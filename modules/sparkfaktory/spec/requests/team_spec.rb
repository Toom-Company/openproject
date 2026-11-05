require "spec_helper"

RSpec.describe "Team org chart and roles", :skip_csrf, type: :rails_request do
  shared_let(:admin) { create(:admin, language: "es") }
  shared_let(:boss) { create(:user, firstname: "Vladimir", lastname: "Moreno") }
  shared_let(:lead) { create(:user, firstname: "Javier", lastname: "Arias") }
  shared_let(:developer) { create(:user, firstname: "Inti", lastname: "Sarmiento") }
  shared_let(:team) { create(:group, lastname: "Spark Dev 1", members: [developer]) }
  shared_let(:other_team) { create(:group, lastname: "Spark Dev 2") }
  shared_let(:member) { create(:user, language: "es") }

  shared_let(:boss_node) { Sparkfaktory::OrgNode.create!(principal: boss, title: "Jefe") }
  shared_let(:lead_node) { Sparkfaktory::OrgNode.create!(principal: lead, title: "Project Líder", parent: boss_node) }
  shared_let(:team_node) { Sparkfaktory::OrgNode.create!(principal: team, parent: lead_node) }

  describe "viewing" do
    before { login_as(member) }

    it "shows the hierarchy with the live members of each team" do
      get sparkfaktory_team_path

      expect(response).to have_http_status(:ok)
      page = Capybara.string(response.body)
      expect(page).to have_css("[data-test-selector='sf-org-node-#{boss_node.id}']", text: "Vladimir Moreno")
      expect(page).to have_css("[data-test-selector='sf-org-node-#{boss_node.id}'] + ul " \
                               "[data-test-selector='sf-org-node-#{lead_node.id}']", text: "Project Líder")
      expect(page).to have_css("[data-test-selector='sf-org-node-#{team_node.id}']", text: "Inti Sarmiento")
      expect(page).to have_no_css("[data-test-selector='sf-org-add']")
      expect(page).to have_no_css("[data-test-selector='sf-org-unplaced']")
    end

    it "does not let a non admin change the chart" do
      post sparkfaktory_org_nodes_path, params: { org_node: { principal_id: member.id } }
      expect(response).to have_http_status(:forbidden)
      expect(Sparkfaktory::OrgNode.where(principal: member)).not_to exist
    end
  end

  describe "editing as admin" do
    before { login_as(admin) }

    it "lists teams that are not placed yet and links to the specialty options" do
      field = create(:user_custom_field, :list, name: "Especialidad")
      Setting.plugin_openproject_sparkfaktory = { "specialty_field_id" => field.id }
      get sparkfaktory_team_path
      expect(Capybara.string(response.body)).to have_link(href: edit_custom_field_path(field))
      expect(Capybara.string(response.body)).to have_css("[data-test-selector='sf-org-unplaced']", text: "Spark Dev 2")
    end

    it "places a team under a leader" do
      post sparkfaktory_org_nodes_path, params: { org_node: { principal_id: other_team.id, parent_id: lead_node.id } }

      expect(response).to redirect_to(sparkfaktory_team_path)
      expect(Sparkfaktory::OrgNode.find_by(principal: other_team).parent).to eq lead_node
    end

    it "lets two leaders lead the same team and marks them in its member list" do
      co_lead = create(:user, firstname: "Hector", lastname: "Perez")
      team.group_users.create!(user: lead)
      co_lead_node = Sparkfaktory::OrgNode.create!(principal: co_lead, title: "Project Líder", parent: boss_node)

      post sparkfaktory_org_nodes_path, params: { org_node: { principal_id: team.id, parent_id: co_lead_node.id } }
      expect(response).to redirect_to(sparkfaktory_team_path)

      get sparkfaktory_team_path
      page = Capybara.string(response.body)
      expect(page).to have_css("[data-test-selector='sf-org-leaders']", text: "Javier Arias y Hector Perez", count: 2)
      expect(page.all("[data-test-selector^='sf-org-node-']", text: "Spark Dev 1").size).to eq 2
      expect(page).to have_css(".sf-org-card--members li", text: /Javier Arias\s+Líder/)
    end

    it "keeps a person in a single place" do
      post sparkfaktory_org_nodes_path, params: { org_node: { principal_id: lead.id, parent_id: nil } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Sparkfaktory::OrgNode.where(principal: lead).count).to eq 1
    end

    it "does not duplicate a shared team when one of its leaders is removed" do
      co_lead_node = Sparkfaktory::OrgNode.create!(principal: create(:user), parent: boss_node)
      Sparkfaktory::OrgNode.create!(principal: team, parent: boss_node)
      Sparkfaktory::OrgNode.create!(principal: team, parent: co_lead_node)

      delete sparkfaktory_org_node_path(co_lead_node)

      expect(Sparkfaktory::OrgNode.where(principal: team, parent: boss_node).count).to eq 1
    end

    it "rejects moving a node below its own descendant" do
      patch sparkfaktory_org_node_path(boss_node), params: { org_node: { parent_id: team_node.id } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(boss_node.reload.parent_id).to be_nil
    end

    it "removes a node and moves its children up" do
      delete sparkfaktory_org_node_path(lead_node)

      expect(Sparkfaktory::OrgNode.exists?(lead_node.id)).to be false
      expect(team_node.reload.parent).to eq boss_node
      expect(lead.reload).to be_present
    end
  end

  describe "roles page" do
    shared_let(:todo) { create(:status, name: "Pendiente", is_default: true, position: 1) }
    shared_let(:review) { create(:status, name: "En revisión", position: 4) }
    shared_let(:done) { create(:status, name: "Completada", is_closed: true, position: 5) }
    shared_let(:type) { create(:type_task) }
    shared_let(:member_role) { create(:project_role, name: "Miembro", permissions: %i[add_work_packages]) }
    shared_let(:leader_role) { create(:project_role, name: "Project Líder", permissions: %i[add_work_packages manage_members]) }

    before do
      [[todo, review]].each { |from, to| create(:workflow, role: member_role, type:, old_status: from, new_status: to) }
      [[todo, review], [review, done], [todo, done], [done, todo], [review, todo], [done, review]]
        .each { |from, to| create(:workflow, role: leader_role, type:, old_status: from, new_status: to) }
      Setting.plugin_openproject_sparkfaktory = { "member_role_id" => member_role.id, "leader_role_id" => leader_role.id }
      login_as(member)
    end

    it "explains per role which statuses it may set" do
      get sparkfaktory_team_roles_path

      expect(response).to have_http_status(:ok)
      page = Capybara.string(response.body)
      member_box = page.find("[data-test-selector='sf-role-#{member_role.id}']")
      expect(member_box).to have_text("No puede marcar tareas como completadas")
      expect(member_box.find("[data-test-selector='sf-transition-#{done.id}']")).to have_text("no puede")
      expect(member_box.find("[data-test-selector='sf-transition-#{review.id}']")).to have_text("solo desde Pendiente")

      leader_box = page.find("[data-test-selector='sf-role-#{leader_role.id}']")
      expect(leader_box.find("[data-test-selector='sf-transition-#{done.id}']")).to have_text("desde cualquier estado")
    end

    it "links admins to the workflow, roles and specialty settings" do
      login_as(admin)
      get sparkfaktory_team_roles_path

      expect(response).to have_http_status(:ok)
      expect(Capybara.string(response.body)).to have_link(href: edit_type_workflow_path(type))
    end
  end
end
