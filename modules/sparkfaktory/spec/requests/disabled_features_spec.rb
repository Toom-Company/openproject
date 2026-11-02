require "spec_helper"

RSpec.describe "Excluded features are unreachable", :skip_csrf, type: :rails_request do
  shared_let(:admin) { create(:admin) }
  shared_let(:project) do
    create(:project, enabled_module_names: %w[work_package_tracking news forums costs budgets backlogs gantt])
  end

  before { login_as(admin) }

  describe "instance pages guarded only by admin?" do
    %w[
      /news /gantt /cost_reports /cost_types /my/time-tracking /portfolios /programs /team_planners
      /admin/costs /admin/cost_types /admin/backlogs /admin/settings/time_entry_activities
      /admin/settings/webhooks /admin/settings/storages /admin/settings/project_phase_definitions
      /admin/enterprise_trial /github_integration/admin/settings /gitlab_integration/admin/settings
    ].each do |path|
      it "answers 404 for #{path}" do
        get path
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "project pages of excluded modules, even when the module is still enabled" do
    %w[news forums budgets backlogs cost_reports roadmap gantt].each do |segment|
      it "denies /projects/:id/#{segment}" do
        get "/projects/#{project.identifier}/#{segment}"
        expect(response.status).to be_in([403, 404])
      end
    end
  end

  describe "API" do
    it "does not allow logging time" do
      post "/api/v3/time_entries",
           params: { hours: "PT1H", _links: { entity: { href: "/api/v3/projects/#{project.id}" } } }.to_json,
           headers: { "CONTENT_TYPE" => "application/json" }

      expect(response.status).to be_in([403, 404, 422])
      expect(TimeEntry.count).to eq 0
    end

    it "does not allow creating versions" do
      post "/api/v3/versions",
           params: { name: "1.0", _links: { definingProject: { href: "/api/v3/projects/#{project.id}" } } }.to_json,
           headers: { "CONTENT_TYPE" => "application/json" }

      expect(response.status).to be_in([403, 422])
      expect(Version.count).to eq 0
    end

    it "does not list news" do
      create(:news, project:)
      get "/api/v3/news"

      body = JSON.parse(response.body)
      expect(response.status == 403 || body["total"].zero?).to be true
    end
  end
end

RSpec.describe "New projects", :skip_csrf, type: :rails_request do
  shared_let(:admin) { create(:admin) }

  before do
    Setting.default_projects_modules = Sparkfaktory::InstanceSetupService::DEFAULT_PROJECT_MODULES
    login_as(admin)
  end

  it "only enable the supported modules" do
    post "/api/v3/projects",
         params: { name: "Proyecto nuevo", identifier: "proyecto-nuevo" }.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }

    expect(response).to have_http_status(:created)
    expect(Project.find_by(identifier: "proyecto-nuevo").enabled_module_names)
      .to match_array(Sparkfaktory::InstanceSetupService::DEFAULT_PROJECT_MODULES)
  end

  it "cannot enable an excluded module through the settings form" do
    project = create(:project, enabled_module_names: %w[work_package_tracking])
    put "/projects/#{project.identifier}/settings/modules",
        params: { project: { enabled_module_names: %w[work_package_tracking news costs gantt] } }

    expect(project.reload.enabled_module_names).not_to include("news", "costs", "gantt")
  end
end
