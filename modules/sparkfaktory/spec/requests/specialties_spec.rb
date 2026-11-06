require "spec_helper"

RSpec.describe "Team specialties", :skip_csrf, type: :rails_request do
  shared_let(:admin) { create(:admin, language: "es") }
  shared_let(:member) { create(:user, language: "es") }
  shared_let(:lead) { create(:user, firstname: "Javier", lastname: "Arias") }
  shared_let(:lead_node) { Sparkfaktory::OrgNode.create!(principal: lead, title: "Project Leader") }
  shared_let(:field) do
    create(:user_custom_field, :list, name: "Especialidad", multi_value: true, editable: false,
                                      possible_values: Sparkfaktory::Specialties.titles)
  end

  let(:project_manager) { field.custom_options.find_by(value: "Project Manager") }
  let(:team_lead) { field.custom_options.find_by(value: "Team Lead") }

  before { Setting.plugin_openproject_sparkfaktory = { "specialty_field_id" => field.id } }

  it "shows everyone's job title and specialties without edit buttons for members" do
    lead.custom_field_values = { field.id => [project_manager.id] }
    lead.save!
    login_as(member)

    get sparkfaktory_specialties_path

    expect(response).to have_http_status(:ok)
    page = Capybara.string(response.body)
    row = page.find("[data-test-selector='sf-specialties-#{lead.id}']")
    expect(row).to have_text("Project Leader")
    expect(row).to have_css(".Label", text: "Project Manager")
    expect(page).to have_no_link(href: edit_sparkfaktory_specialty_path(lead))
  end

  it "does not let members edit specialties" do
    login_as(member)
    patch sparkfaktory_specialty_path(lead), params: { specialty_ids: [team_lead.id] }

    expect(response).to have_http_status(:forbidden)
    expect(Sparkfaktory::Specialties.for(lead.reload, field)).to be_empty
  end

  describe "as admin" do
    before { login_as(admin) }

    it "groups the options by category" do
      get edit_sparkfaktory_specialty_path(lead)

      expect(response).to have_http_status(:ok)
      groups = Capybara.string(response.body).all("[data-test-selector='sf-specialty-group'] legend").map(&:text)
      expect(groups).to eq ["Desarrollo de software", "IT y tecnología", "Liderazgo y gestión",
                            "Datos e inteligencia artificial", "Pruebas y control de calidad", "UI/UX y diseño",
                            "Tecnologías emergentes"]
    end

    it "sets the specialties and the org chart title in one go" do
      patch sparkfaktory_specialty_path(lead),
            params: { specialty_ids: ["", project_manager.id, team_lead.id], title: "Project Manager" }

      expect(response).to redirect_to(sparkfaktory_specialties_path)
      expect(Sparkfaktory::Specialties.for(lead.reload, field)).to contain_exactly("Project Manager", "Team Lead")
      expect(lead_node.reload.title).to eq "Project Manager"
    end

    it "clears the specialties when nothing is ticked" do
      lead.custom_field_values = { field.id => [project_manager.id] }
      lead.save!

      patch sparkfaktory_specialty_path(lead), params: { specialty_ids: [""] }

      expect(Sparkfaktory::Specialties.for(lead.reload, field)).to be_empty
      expect(lead_node.reload.title).to eq "Project Leader"
    end
  end
end
