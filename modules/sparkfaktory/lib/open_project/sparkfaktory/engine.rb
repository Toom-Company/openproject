#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

require "open_project/plugins"
require "open_project/sparkfaktory/disabled_routes"
require "open_project/sparkfaktory/email_obfuscation_opt_out"

module OpenProject::Sparkfaktory
  class Engine < ::Rails::Engine
    engine_name :openproject_sparkfaktory

    include OpenProject::Plugins::ActsAsOpEngine

    register "openproject-sparkfaktory",
             author_url: "https://proyectos.sparkfaktory.com",
             bundled: true,
             settings: { default: { "blocked_status_id" => nil, "setup_version" => nil } }

    initializer "openproject_sparkfaktory.disabled_routes" do |app|
      app.config.middleware.use OpenProject::Sparkfaktory::DisabledRoutes
    end

    initializer "openproject_sparkfaktory.email_obfuscation_opt_out" do |app|
      app.config.middleware.use OpenProject::Sparkfaktory::EmailObfuscationOptOut
    end

    config.to_prepare do
      ::WorkPackages::Menu.prepend(OpenProject::Sparkfaktory::Patches::WorkPackagesMenuPatch)
      ::Redmine::MenuManager::TopMenuHelper.prepend(OpenProject::Sparkfaktory::Patches::TopMenuHelperPatch)
      ::Redmine::MenuManager::TopMenu::HelpMenu.prepend(OpenProject::Sparkfaktory::Patches::HelpMenuPatch)
      ::Source::SeedDataLoader.prepend(OpenProject::Sparkfaktory::Patches::SeedDataLoaderPatch)
      ::Overviews::Workspaces::ProjectOverviewGridComponent.prepend(
        OpenProject::Sparkfaktory::Patches::ProjectOverviewGridPatch
      )
    end

    # Runs after every plugin has registered its permissions, menus and locales,
    # and again on each code reload in development.
    config.after_initialize do
      OpenProject::Sparkfaktory::Customization.apply!
      OpenProject::Sparkfaktory::Navigation.register!
      OpenProject::Sparkfaktory::Homescreen.register!
      OpenProject::Sparkfaktory::LocaleOverrides.load!

      Rails.application.reloader.to_prepare do
        OpenProject::Sparkfaktory::Customization.apply!
        OpenProject::Sparkfaktory::LocaleOverrides.load!
      end
    end
  end
end
