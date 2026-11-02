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

module OpenProject::Sparkfaktory
  # Applies the Sparkfaktory feature set on top of the registered OpenProject modules:
  # excluded modules lose their permissions (server side, UI and API alike), selected
  # permissions and controller actions are withdrawn and the menus are reduced to the
  # supported navigation.
  module Customization
    module_function

    DISABLED_PROJECT_MODULES = %i[
      backlogs
      bim
      budgets
      costs
      documents
      forums
      gantt
      github
      gitlab
      news
      repository
      resource_management
      team_planner_view
    ].freeze

    DISABLED_PERMISSIONS = %i[
      add_portfolios
      add_programs
      assign_versions
      edit_project_phases
      manage_file_links
      manage_files_in_project
      manage_versions
      select_project_phases
      view_file_links
      view_project_phases
    ].freeze

    WITHDRAWN_CONTROLLER_ACTIONS = {
      view_work_packages: %r{\Aversions/},
      edit_project: %r{\Aprojects/settings/creation_wizard/},
      edit_project_attributes: %r{\Aprojects/creation_wizard/},
      export_projects: %r{\Aprojects/export_project_initiation_pdf\z}
    }.freeze

    def apply!
      OpenProject::Plugins::ModuleHandler.disable_modules!(disabled_project_modules)
      hide_disabled_modules!
      disable_permissions!
      withdraw_controller_actions!
      OpenProject::AccessControl.clear_caches
    end

    def disabled_project_modules
      DISABLED_PROJECT_MODULES - reenabled_project_modules
    end

    # Escape hatch for operators: SPARKFAKTORY_REENABLE_MODULES="news,forums"
    def reenabled_project_modules
      ENV.fetch("SPARKFAKTORY_REENABLE_MODULES", "").split(/[\s,]+/).compact_blank.map(&:to_sym)
    end

    # Modules without own permissions (e.g. gantt) stay selectable unless their
    # registration condition fails.
    def hide_disabled_modules!
      names = disabled_project_modules
      OpenProject::AccessControl.modules
        .select { |mod| mod[:name] && names.include?(mod[:name].to_sym) }
        .each { |mod| mod[:if] = -> { false } }
    end

    def disable_permissions!
      OpenProject::AccessControl.permissions
        .select { |permission| DISABLED_PERMISSIONS.include?(permission.name) }
        .each(&:disable!)
    end

    def withdraw_controller_actions!
      WITHDRAWN_CONTROLLER_ACTIONS.each do |permission_name, pattern|
        OpenProject::AccessControl.permission(permission_name)&.controller_actions&.reject! { |action| action.match?(pattern) }
      end
    end
  end
end
