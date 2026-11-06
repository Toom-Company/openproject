require "spec_helper"

RSpec.describe Sparkfaktory::InstanceSetupService do
  shared_let(:admin_role) { create(:project_role, name: "Project admin", permissions: %i[view_work_packages manage_members archive_project]) }
  shared_let(:status) { create(:status, name: "Bloqueada") }
  shared_let(:template) { create(:project, identifier: "plantilla-proyecto") }

  before { Setting.new_project_user_role_id = admin_role.id }

  subject(:call) { described_class.new.call }

  it "configures the instance once and leaves later admin changes alone" do
    call
    expect(Setting.app_title).to eq "Sparkfaktory Proyectos"
    expect(Setting.default_language).to eq "es"
    expect(Setting.ee_hide_banners?).to be true
    expect(Setting.login_required?).to be true

    Setting.app_title = "Otro nombre"
    described_class.new.call
    expect(Setting.app_title).to eq "Otro nombre"
  end

  it "creates the leader role without instance-level permissions and marks the template" do
    call

    leader = ProjectRole.find_by(name: "Project Líder")
    expect(leader.permissions).to include(:manage_members)
    expect(leader.permissions).not_to include(:archive_project)
    expect(admin_role.reload.name).to eq "Jefe"
    expect(Setting.new_project_user_role_id.to_i).to eq leader.id
    expect(template.reload).to be_templated
    expect(Setting.plugin_openproject_sparkfaktory["blocked_status_id"]).to eq status.id
  end

  context "with every transition open to every role" do
    let(:type) { create(:type_task) }
    let(:todo) { create(:status, name: "Pendiente", is_default: true) }
    let(:review) { create(:status, name: "En revisión") }
    let(:done) { create(:status, name: "Completada", is_closed: true) }
    let!(:member_role) { create(:project_role, name: "Member") }
    let(:statuses) { [todo, status, review, done] }

    before do
      [member_role, admin_role].each do |role|
        statuses.permutation(2).each { |from, to| create(:workflow, role:, type:, old_status: from, new_status: to) }
      end
    end

    def targets(role, from)
      Workflow.where(role:, old_status: from).pluck(:new_status_id)
    end

    it "lets members move tasks up to review and leaves approval to leaders" do
      call
      leader = ProjectRole.find_by(name: "Project Líder")

      expect(member_role.reload.name).to eq "Miembro"
      expect(targets(member_role, todo)).to contain_exactly(status.id, review.id)
      expect(targets(member_role, review)).to be_empty
      expect(targets(member_role, done)).to be_empty
      expect(targets(leader, review)).to contain_exactly(todo.id, status.id, done.id)
      expect(targets(admin_role, done)).to contain_exactly(todo.id, status.id, review.id)
    end

    it "restricts only once so later workflow changes survive" do
      call
      create(:workflow, role: member_role, type:, old_status: review, new_status: done)

      described_class.new.call
      expect(targets(member_role, review)).to eq [done.id]
    end
  end

  it "creates the multi-value specialty field for users" do
    call
    field = UserCustomField.find(Setting.plugin_openproject_sparkfaktory["specialty_field_id"])

    expect(field.name).to eq "Especialidad"
    expect(field).to be_multi_value
    expect(field.possible_values.map(&:value)).to eq Sparkfaktory::Specialties.titles
    expect(field.possible_values.first(2).map(&:value)).to eq ["Software Developer", "Software Engineer"]

    user = create(:user)
    user.custom_field_values = { field.id => field.custom_options.first(2).map(&:id) }
    user.save!
    expect(Sparkfaktory::Specialties.for(user.reload)).to contain_exactly("Software Developer", "Software Engineer")
  end

  it "replaces the old specialty options with the catalog without touching the ones in use" do
    field = create(:user_custom_field, :list, name: "Especialidad", multi_value: true,
                                               possible_values: %w[Backend Frontend Diseño])
    backend = field.custom_options.find_by(value: "Backend")
    user = create(:user)
    user.custom_field_values = { field.id => [backend.id] }
    user.save!
    Setting.plugin_openproject_sparkfaktory = { "specialty_field_id" => field.id, "setup_version" => 2 }

    call

    values = field.reload.custom_options.order(:position).map(&:value)
    expect(values).to eq Sparkfaktory::Specialties.titles + ["Backend"]
    expect(Sparkfaktory::Specialties.for(user.reload)).to eq ["Backend"]
  end

  it "adds project start and end dates as project attributes" do
    call
    expect(ProjectCustomField.where(field_format: "date").pluck(:name)).to contain_exactly("Fecha de inicio", "Fecha de fin")
  end
end

RSpec.describe Sparkfaktory::AdminAccountsService do
  let(:emails) { %w[ana.lopez@example.com Luis.Gil@example.com] }

  it "creates active administrators with a temporary password that must be changed" do
    accounts = described_class.new(emails:).call.result

    expect(accounts.map(&:mail)).to eq %w[ana.lopez@example.com luis.gil@example.com]
    user = User.find_by(mail: "ana.lopez@example.com")
    expect(user).to be_admin
    expect(user).to be_active
    expect(user.force_password_change).to be true
    expect(user.check_password?(accounts.first.password)).to be true
    expect(user.name).to eq "Ana Lopez"
  end

  it "locks the generic admin account once named administrators exist" do
    generic = create(:admin, login: "admin")
    described_class.new(emails:).call

    expect(generic.reload).to be_locked
  end

  it "does not reset existing passwords unless asked" do
    first = described_class.new(emails:).call.result.first
    again = described_class.new(emails:).call.result.first

    expect(again.password).to be_nil
    expect(User.find_by(mail: first.mail).check_password?(first.password)).to be true
  end
end
