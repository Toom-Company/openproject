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

    leader = ProjectRole.find_by(name: "Líder")
    expect(leader.permissions).to include(:manage_members)
    expect(leader.permissions).not_to include(:archive_project)
    expect(admin_role.reload.name).to eq "Administrador"
    expect(template.reload).to be_templated
    expect(Setting.plugin_openproject_sparkfaktory["blocked_status_id"]).to eq status.id
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
