require "spec_helper"

RSpec.describe "Tasks for project members", :skip_csrf, type: :rails_request do
  include API::V3::Utilities::PathHelper

  shared_let(:todo) { create(:status, name: "Pendiente", is_default: true, position: 1) }
  shared_let(:in_progress) { create(:status, name: "En progreso", position: 2) }
  shared_let(:blocked) { create(:status, name: "Bloqueada", position: 3) }
  shared_let(:done) { create(:status, name: "Completada", is_closed: true, position: 5) }
  shared_let(:priority) { create(:default_priority) }
  shared_let(:type) { create(:type_task) }

  shared_let(:member_role) do
    create(:project_role, name: "Miembro",
                          permissions: %i[view_work_packages add_work_packages edit_work_packages
                                          change_work_package_status manage_subtasks manage_work_package_relations
                                          add_work_package_comments add_work_package_attachments work_package_assigned
                                          view_members show_board_views save_queries])
  end
  shared_let(:project) { create(:project, types: [type], enabled_module_names: %w[work_package_tracking board_view]) }
  shared_let(:other_project) { create(:project, types: [type], public: false, enabled_module_names: %w[work_package_tracking]) }
  shared_let(:user) { create(:user, member_with_roles: { project => member_role }) }
  shared_let(:teammate) { create(:user, member_with_roles: { project => member_role }) }
  shared_let(:outsider_task) { create(:work_package, project: other_project, type:, status: todo, subject: "Privado") }

  # Members may go forward through the board but never reopen a completed task.
  shared_let(:workflows) do
    [[todo, in_progress], [in_progress, blocked], [blocked, in_progress], [in_progress, done], [todo, done]]
      .each { |from, to| create(:workflow, role: member_role, type:, old_status: from, new_status: to) }
  end

  let(:json) { { "CONTENT_TYPE" => "application/json" } }

  before { login_as(user) }

  def create_task(subject, parent: nil)
    links = { type: { href: api_v3_paths.type(type.id) } }
    links[:parent] = { href: api_v3_paths.work_package(parent.id) } if parent
    post api_v3_paths.work_packages_by_project(project.id), params: { subject:, _links: links }.to_json, headers: json
    expect(response).to have_http_status(:created), response.body
    WorkPackage.find(JSON.parse(response.body)["id"])
  end

  def patch_task(task, attributes)
    patch api_v3_paths.work_package(task.id), params: attributes.merge(lockVersion: task.reload.lock_version).to_json,
                                              headers: json
  end

  it "creates tasks and subtasks, assigns them and moves them through the allowed states" do
    task = create_task("Preparar presentación")
    subtask = create_task("Recoger datos", parent: task)
    expect(subtask.parent).to eq task

    patch_task(task, _links: { assignee: { href: api_v3_paths.user(teammate.id) } }, dueDate: Date.tomorrow.iso8601)
    expect(response).to have_http_status(:ok), response.body
    expect(task.reload.assigned_to).to eq teammate

    patch_task(task, _links: { status: { href: api_v3_paths.status(in_progress.id) } })
    expect(response).to have_http_status(:ok)
    patch_task(task, _links: { status: { href: api_v3_paths.status(done.id) } })
    expect(response).to have_http_status(:ok)
    expect(task.reload.status).to eq done
    expect(task.status).to be_is_closed

    patch_task(task, _links: { status: { href: api_v3_paths.status(todo.id) } })
    expect(response).to have_http_status(:unprocessable_entity)
    expect(task.reload.status).to eq done
  end

  it "persists a Kanban move as a status change visible to the column query" do
    task = create_task("Tarjeta")
    column = Queries::CreateService.new(user:)
                                   .call(project:, name: "Bloqueada", public: true,
                                         filters: [{ "status_id" => { "operator" => "=", "values" => [blocked.id.to_s] } }])
                                   .result
    expect(column.results.work_packages).not_to include(task)

    patch_task(task, _links: { status: { href: api_v3_paths.status(in_progress.id) } })
    patch_task(task, _links: { status: { href: api_v3_paths.status(blocked.id) } })
    expect(response).to have_http_status(:ok)

    expect(Query.find(column.id).results.work_packages).to include(task)
  end

  it "keeps comments, attachments and the change history" do
    task = create_task("Con historial")

    post api_v3_paths.work_package_activities(task.id), params: { comment: { raw: "Revisado" } }.to_json, headers: json
    expect(response).to have_http_status(:created)

    file = Rack::Test::UploadedFile.new(StringIO.new("contenido"), "text/plain", original_filename: "nota.txt")
    post api_v3_paths.attachments_by_work_package(task.id),
         params: { metadata: { fileName: "nota.txt" }.to_json, file: }
    expect(response).to have_http_status(:created), response.body

    patch_task(task, subject: "Con historial (editada)")

    get api_v3_paths.work_package_activities(task.id)
    activities = JSON.parse(response.body).dig("_embedded", "elements")
    expect(activities.size).to be >= 3
    expect(activities.filter_map { it.dig("comment", "raw") }).to include("Revisado")
    expect(task.reload.attachments.map(&:filename)).to eq ["nota.txt"]
  end

  it "lists my tasks across projects without leaking private projects" do
    own = create_task("Mía")
    patch_task(own, _links: { assignee: { href: api_v3_paths.user(user.id) } })
    create_task("De otra persona")

    filters = [{ assignee: { operator: "=", values: ["me"] } }, { status: { operator: "o", values: [] } }].to_json
    get api_v3_paths.path_for(:work_packages, filters:)
    subjects = JSON.parse(response.body).dig("_embedded", "elements").pluck("subject")

    expect(subjects).to eq ["Mía"]

    get api_v3_paths.path_for(:work_packages, filters: [].to_json, page_size: 100)
    expect(JSON.parse(response.body).dig("_embedded", "elements").pluck("subject")).not_to include("Privado")

    get api_v3_paths.work_package(outsider_task.id)
    expect(response).to have_http_status(:not_found)
    get api_v3_paths.project(other_project.id)
    expect(response).to have_http_status(:not_found)
    get "/projects/#{other_project.identifier}"
    expect(response.status).to be_in([403, 404])
  end

  it "rejects actions outside the role permissions" do
    task = create_task("Protegida")

    delete api_v3_paths.work_package(task.id)
    expect(response).to have_http_status(:forbidden)
    expect(WorkPackage.exists?(task.id)).to be true

    post api_v3_paths.memberships,
         params: { _links: { project: { href: api_v3_paths.project(project.id) },
                             principal: { href: api_v3_paths.user(create(:user).id) },
                             roles: [{ href: api_v3_paths.role(member_role.id) }] } }.to_json,
         headers: json
    expect(response).to have_http_status(:forbidden)
  end
end
