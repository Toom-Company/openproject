require "spec_helper"

RSpec.describe OpenProject::Sparkfaktory::Customization do
  let(:excluded_modules) { described_class::DISABLED_PROJECT_MODULES }

  it "keeps only the supported project modules selectable" do
    expect(OpenProject::AccessControl.available_project_modules)
      .to contain_exactly(:activity, :board_view, :calendar_view, :meetings, :work_package_tracking)
  end

  it "removes every permission of the excluded modules" do
    leaked = OpenProject::AccessControl.permissions.select { |p| excluded_modules.include?(p.project_module&.to_sym) }

    expect(leaked).to be_empty
  end

  it "disables versions, project phases, portfolios and file storages" do
    described_class::DISABLED_PERMISSIONS.each do |name|
      expect(OpenProject::AccessControl.permission(name)).to be_nil, "#{name} is still enabled"
    end
  end

  it "no longer maps the roadmap to viewing work packages" do
    expect(OpenProject::AccessControl.permission(:view_work_packages).controller_actions.grep(/\Aversions/)).to be_empty
  end

  it "keeps the permissions the supported features rely on" do
    %i[view_work_packages add_work_packages edit_work_packages change_work_package_status manage_subtasks
       manage_work_package_relations add_work_package_attachments add_work_package_comments
       show_board_views manage_board_views view_calendar view_meetings create_meetings
       view_wiki_pages edit_wiki_pages manage_members add_subprojects].each do |name|
      expect(OpenProject::AccessControl.permission(name)).to be_present, "#{name} is missing"
    end
  end
end

RSpec.describe OpenProject::Sparkfaktory::Navigation do
  shared_let(:admin) { create(:admin) }

  def item_names(menu, project = nil)
    Redmine::MenuManager.items(menu, project).children.map(&:name)
  end

  before { User.current = admin }

  it "orders the global navigation" do
    expect(item_names(:global_menu)).to start_with(:home, :work_packages, :projects)
    expect(item_names(:global_menu)).to include(:calendar_view, :meetings, :wikis, :administration)
  end

  it "hides excluded entries in every menu" do
    described_class::HIDDEN_ITEMS.each do |menu, names|
      expect(item_names(menu) & names).to be_empty, "#{menu} still contains #{item_names(menu) & names}"
    end
  end

  it "labels the work package entry as my tasks" do
    item = Redmine::MenuManager.items(:global_menu).children.find { it.name == :work_packages }

    I18n.with_locale(:es) { expect(item.caption).to eq("Mis tareas") }
  end
end

RSpec.describe OpenProject::Sparkfaktory::LocaleOverrides do
  it "uses the task wording in Spanish on the server and in the frontend bundle" do
    I18n.with_locale(:es) do
      expect(I18n.t(:label_work_package_plural)).to eq("Tareas")
      expect(I18n.t("js.label_work_package_plural")).to eq("Tareas")
      expect(I18n.t(:label_work_package_new)).to eq("Nueva tarea")
    end
  end

  it "keeps other languages untouched" do
    I18n.with_locale(:en) { expect(I18n.t(:label_work_package_plural)).to eq("Work packages") }
  end
end
