module Sparkfaktory
  # Imports users, teams, projects, shares and tasks from a JSON export of a Vikunja
  # database (see docs/sparkfaktory/OPERACION.md). Re-runnable: existing users, groups,
  # projects and memberships are reused, and tasks are only imported into projects
  # created by the same run.
  class VikunjaImportService
    Report = Struct.new(:users_created, :users_reused, :groups, :projects_created, :projects_skipped,
                        :memberships, :tasks, :passwords, :warnings, keyword_init: true)

    TEMPLATE_IDENTIFIER = "plantilla-proyecto".freeze
    COPIED_FROM_TEMPLATE = %w[queries boards wiki overview categories].freeze

    def initialize(data:, actor:, email_domain_map: {}, dry_run: true)
      @data = data.deep_stringify_keys
      @actor = actor
      @email_domain_map = email_domain_map
      @dry_run = dry_run
      @report = Report.new(users_created: [], users_reused: [], groups: [], projects_created: [], projects_skipped: [],
                           memberships: 0, tasks: 0, passwords: {}, warnings: [])
    end

    def call
      ActiveRecord::Base.transaction do
        User.execute_as(@actor) do
          import_users
          import_teams
          import_projects
        end
        raise ActiveRecord::Rollback if @dry_run
      end

      ServiceResult.success(result: @report)
    end

    def mail_for(email)
      local, domain = email.to_s.strip.downcase.split("@", 2)
      "#{local}@#{@email_domain_map.fetch(domain, domain)}"
    end

    private

    def import_users
      @users = rows("users").to_h do |row|
        mail = mail_for(row["email"])
        user = User.where("LOWER(mail) = ?", mail).first
        if user
          @report.users_reused << mail
        else
          user = create_user(row, mail)
          @report.users_created << mail
        end
        [row["id"], user]
      end
    end

    def create_user(row, mail)
      firstname, lastname = split_name(row["name"].presence || row["username"])
      password = "Sf#{SecureRandom.alphanumeric(14)}-#{SecureRandom.random_number(90) + 10}"
      user = User.new(login: mail, mail:, firstname:, lastname:, status: :active, language: "es",
                      password:, password_confirmation: password, force_password_change: true)
      user.save!
      @report.passwords[mail] = password
      user
    end

    def split_name(name)
      first, rest = name.to_s.strip.split(/\s+/, 2)
      [first.presence || name, rest.presence || first.presence || name]
    end

    def import_teams
      @groups = rows("teams").to_h do |row|
        group = Group.find_by(lastname: row["name"]) || Group.create!(lastname: row["name"])
        members = Array(row["members"]).filter_map { |id| @users[id] } - group.users
        Groups::AddUsersService.new(group, current_user: @actor).call(ids: members.map(&:id), send_notifications: false) if members.any?
        @report.groups << "#{row['name']} (#{group.reload.users.count})"
        [row["id"], group]
      end
    end

    def import_projects
      rows("projects").sort_by { |row| row["parent_id"].to_i }.each do |row|
        if row["task_count"].to_i.zero? && row["share_count"].to_i.zero?
          @report.projects_skipped << "#{row['title']} (#{row['id']}, vacío y sin compartir)"
          next
        end

        identifier = identifier_for(row["title"])
        project = Project.find_by(identifier:)
        if project
          @report.projects_skipped << "#{row['title']} (ya existe como #{identifier})"
        else
          project = create_project(row, identifier)
          @report.projects_created << "#{project.name} → /projects/#{identifier}"
          add_memberships(row, project)
          import_tasks(row, project)
          next
        end

        add_memberships(row, project)
      end
    end

    def create_project(row, identifier)
      params = { name: row["title"], identifier:, description: html_to_markdown(row["description"]), public: false,
                 parent_id: parent_project_id(row) }.compact
      project = if template
                  Projects::CopyService.new(user: @actor, source: template)
                                       .call(target_project_params: params, only: COPIED_FROM_TEMPLATE, send_notifications: false)
                                       .result
                else
                  Projects::CreateService.new(user: @actor).call(params).result
                end
      raise "No se pudo crear el proyecto #{row['title']}" unless project&.persisted?

      project.update_columns(active: false) if row["archived"]
      (@projects ||= {})[row["id"]] = project
    end

    def template
      @template ||= Project.find_by(identifier: TEMPLATE_IDENTIFIER)
    end

    def parent_project_id(row)
      row["parent_id"] && @projects&.dig(row["parent_id"])&.id
    end

    def identifier_for(title)
      base = title.to_s.parameterize.presence || "proyecto"
      base = "#{base}-proyecto" if base.match?(/\A\d/) || base.length < 3
      base[0, 90]
    end

    def add_memberships(row, project)
      owner = @users[row["owner_id"]]
      grant(project, owner, admin_role) if owner

      rows("user_shares").select { it["project_id"] == row["id"] }.each do |share|
        grant(project, @users[share["user_id"]], role_for(share["permission"]))
      end

      rows("team_shares").select { it["project_id"] == row["id"] }.each do |share|
        grant(project, @groups[share["team_id"]], role_for(share["permission"]))
      end
    end

    def grant(project, principal, role)
      return if principal.nil? || role.nil?

      member = Member.find_by(project:, principal:, entity: nil)
      if member
        return if member.roles.include?(role)

        member.roles << role
      else
        Members::CreateService.new(user: @actor).call(project:, principal:, roles: [role], send_notifications: false)
                              .on_failure { |result| @report.warnings << "#{principal.name} en #{project.name}: #{result.message}" }
      end
      @report.memberships += 1
    end

    # Vikunja permissions: 0 read, 1 read & write, 2 admin.
    def role_for(permission)
      permission.to_i == 2 ? admin_role : member_role
    end

    def admin_role
      @admin_role ||= ProjectRole.find_by(id: Setting.new_project_user_role_id) || ProjectRole.find_by(name: "Administrador")
    end

    def member_role
      @member_role ||= ProjectRole.find_by(name: "Miembro") || ProjectRole.givable.find_by(builtin: Role::NON_BUILTIN)
    end

    def import_tasks(row, project)
      rows("tasks").select { it["project_id"] == row["id"] }.each do |task|
        result = WorkPackages::CreateService.new(user: @actor).call(**task_attributes(task, project), send_notifications: false)
        if result.success?
          preserve_origin(result.result, task)
          @report.tasks += 1
        else
          @report.warnings << "Tarea #{task['id']} «#{task['title']}»: #{result.errors.full_messages.join(', ')}"
        end
      end
    end

    def preserve_origin(work_package, task)
      author = @users[task["created_by_id"]]
      columns = { created_at: task["created"], updated_at: task["updated"] }.compact
      columns[:author_id] = author.id if author
      work_package.update_columns(columns) if columns.any?
      work_package.journals.update_all(user_id: author.id) if author
    end

    def task_attributes(task, project)
      {
        project:,
        type: task_type(project),
        subject: task["title"].to_s.truncate(255),
        description: html_to_markdown(task["description"]),
        status: status_for(task),
        priority: priority_for(task["priority"]),
        assigned_to: Array(task["assignee_ids"]).filter_map { @users[it] }.first,
        start_date: task["start_date"],
        due_date: task["due_date"]
      }.compact
    end

    def task_type(_project)
      @task_type ||= Type.find_by(name: %w[Tarea Task]) || Type.order(:position).first
    end

    def status_for(task)
      return closed_status if task["done"] || task["bucket"].to_s.casecmp?("done")
      return in_progress_status if task["bucket"].to_s.casecmp?("doing")

      Status.default
    end

    def closed_status
      @closed_status ||= Status.where(is_closed: true).order(:position).first
    end

    def in_progress_status
      @in_progress_status ||= Status.find_by(name: ["En progreso", "In progress"]) || Status.default
    end

    # Vikunja priorities: 0 unset, 1 low, 2 medium, 3 high, 4 urgent, 5 do now.
    def priority_for(value)
      names = { 1 => %w[Baja Low], 3 => %w[Alta High], 4 => %w[Urgente Urgent], 5 => %w[Urgente Urgent] }
      IssuePriority.find_by(name: names[value.to_i]) || IssuePriority.default
    end

    def html_to_markdown(html)
      return nil if html.blank?

      fragment = Nokogiri::HTML::DocumentFragment.parse(html)
      text = fragment.children.map { |node| markdown_for(node) }.join.gsub(/\n{3,}/, "\n\n").strip
      text.presence
    end

    def markdown_for(node)
      case node.name
      when "text" then node.text
      when "p" then "#{inline(node)}\n\n"
      when "br" then "\n"
      when "ul" then "#{node.css('> li').map { |li| "- #{inline(li).strip}" }.join("\n")}\n\n"
      when "ol" then "#{node.css('> li').each_with_index.map { |li, i| "#{i + 1}. #{inline(li).strip}" }.join("\n")}\n\n"
      else inline(node)
      end
    end

    def inline(node)
      node.children.map do |child|
        case child.name
        when "text" then child.text
        when "br" then "\n"
        when "code" then "`#{child.text}`"
        when "strong", "b" then "**#{inline(child)}**"
        when "em", "i" then "_#{inline(child)}_"
        when "a" then "[#{inline(child)}](#{child['href']})"
        when "ul", "ol", "p" then "\n#{markdown_for(child)}"
        else inline(child)
        end
      end.join
    end

    def rows(key)
      Array(@data[key])
    end
  end
end
