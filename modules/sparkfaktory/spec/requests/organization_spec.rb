require "spec_helper"

RSpec.describe "Teams, meetings and documentation", :skip_csrf, type: :rails_request do
  include API::V3::Utilities::PathHelper

  shared_let(:type) { create(:type_task) }
  shared_let(:status) { create(:default_status) }
  shared_let(:priority) { create(:default_priority) }
  shared_let(:leader_role) do
    create(:project_role, name: "Líder", permissions: %i[view_work_packages edit_work_packages manage_members view_members
                                                        view_meetings create_meetings edit_meetings manage_agendas
                                                        view_wiki_pages edit_wiki_pages manage_wiki])
  end
  shared_let(:member_role) do
    create(:project_role, name: "Miembro", permissions: %i[view_work_packages view_members view_meetings view_wiki_pages])
  end
  shared_let(:alpha) do
    create(:project, types: [type], enabled_module_names: %w[work_package_tracking meetings])
  end
  shared_let(:beta) do
    create(:project, types: [type], enabled_module_names: %w[work_package_tracking meetings])
  end
  shared_let(:user) { create(:user, member_with_roles: { alpha => leader_role, beta => member_role }) }
  shared_let(:team_member) { create(:user) }
  shared_let(:team) { create(:group, lastname: "Equipo diseño", members: [team_member]) }

  let(:json) { { "CONTENT_TYPE" => "application/json" } }

  before { login_as(user) }

  it "applies a different role per project" do
    expect(user.allowed_in_project?(:manage_members, alpha)).to be true
    expect(user.allowed_in_project?(:manage_members, beta)).to be false
  end

  it "lets a leader add a team (group) to the project and its users inherit the role" do
    post api_v3_paths.memberships,
         params: { _links: { project: { href: api_v3_paths.project(alpha.id) },
                             principal: { href: api_v3_paths.group(team.id) },
                             roles: [{ href: api_v3_paths.role(member_role.id) }] } }.to_json,
         headers: json

    expect(response).to have_http_status(:created), response.body
    expect(team_member.reload.allowed_in_project?(:view_work_packages, alpha)).to be true
    expect(team_member.allowed_in_project?(:view_work_packages, beta)).to be false
  end

  it "does not let a plain member manage memberships" do
    post api_v3_paths.memberships,
         params: { _links: { project: { href: api_v3_paths.project(beta.id) },
                             principal: { href: api_v3_paths.group(team.id) },
                             roles: [{ href: api_v3_paths.role(member_role.id) }] } }.to_json,
         headers: json

    expect(response).to have_http_status(:forbidden)
  end

  it "links tasks to meeting agenda items and hides meetings of foreign projects" do
    task = create(:work_package, project: alpha, type:, status:)
    meeting = create(:meeting, project: alpha, author: user, title: "Seguimiento")
    create(:meeting_agenda_item, meeting:, work_package: task, author: user)
    foreign = create(:meeting, project: create(:project, enabled_module_names: %w[meetings]))

    expect(meeting.agenda_items.map(&:work_package)).to eq [task]

    get "/projects/#{alpha.identifier}/meetings/#{meeting.id}"
    expect(response).to have_http_status(:ok)
    get "/meetings/#{foreign.id}"
    expect(response.status).to be_in([403, 404])
  end

  it "keeps the wiki readable for members and writable only with permission" do
    page = create(:wiki_page, wiki: create(:wiki, project: beta), title: "Normas internas", text: "Contenido")

    get "/projects/#{beta.identifier}/wiki/#{page.slug}"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Contenido")

    get "/projects/#{beta.identifier}/wiki/#{page.slug}/edit"
    expect(response).to have_http_status(:forbidden)
  end
end

RSpec.describe "Home screen", :skip_csrf, type: :rails_request do
  shared_let(:type) { create(:type_task) }
  shared_let(:open_status) { create(:default_status) }
  shared_let(:priority) { create(:default_priority) }
  shared_let(:role) { create(:project_role, permissions: %i[view_work_packages]) }
  shared_let(:mine) { create(:project, name: "Proyecto visible", types: [type]) }
  shared_let(:hidden) { create(:project, name: "Proyecto oculto", public: false, types: [type]) }
  shared_let(:user) { create(:user, member_with_roles: { mine => role }) }

  before do
    create(:work_package, project: mine, type:, status: open_status, assigned_to: user, subject: "Tarea propia vencida",
                          start_date: 5.days.ago, due_date: 2.days.ago)
    create(:work_package, project: hidden, type:, status: open_status, subject: "Tarea secreta",
                          start_date: Date.current, due_date: Date.tomorrow)
    login_as(user)
  end

  it "shows real data limited to authorized projects" do
    get "/"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Proyecto visible", "Tarea propia vencida")
    expect(response.body).not_to include("Proyecto oculto", "Tarea secreta")
    expect(response.body).not_to include("homescreen-blocks-upsell")
  end
end
