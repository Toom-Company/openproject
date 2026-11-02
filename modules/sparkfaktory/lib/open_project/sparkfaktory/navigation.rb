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
  module Navigation
    module_function

    HIDDEN_ITEMS = {
      top_menu: %i[activity boards cost_reports_global gantt my_page my_time_tracking news portfolios team_planners],
      global_menu: %i[activity boards cost_reports_global gantt my_page my_time_tracking news portfolios team_planners],
      account_menu: %i[timers],
      project_menu: %i[
        backlogs budgets costs forums gantt news repository resource_management roadmap team_planner_view
        settings_backlogs settings_creation_wizard settings_life_cycle_steps settings_project_storages
        settings_repository settings_time_and_costs settings_versions
      ],
      admin_menu: %i[
        admin_costs cost_types costs_settings custom_actions external_file_storages placeholder_users
        plugin_webhooks project_phase_definitions_settings time_entry_activities
      ],
      work_package_split_view: %i[github gitlab]
    }.freeze

    GLOBAL_ORDER = %i[home work_packages projects calendar_view meetings wikis administration].freeze

    PROJECT_ORDER = %i[overview work_packages boards calendar_view meetings wiki members settings].freeze

    def register!
      HIDDEN_ITEMS.each do |menu_name, item_names|
        Redmine::MenuManager.map(menu_name) do |menu|
          item_names.each { |name| menu.delete(name) }
          hide_unlicensed_enterprise_items(menu)
        end
      end

      Redmine::MenuManager.map(:global_menu) { |menu| customize_global_menu(menu) }
      Redmine::MenuManager.map(:top_menu) { |menu| customize_top_menu(menu) }
      Redmine::MenuManager.map(:project_menu) { |menu| menu.reorder(PROJECT_ORDER) }
    end

    # Menu entries for Enterprise features would otherwise render as upsell links.
    def hide_unlicensed_enterprise_items(menu)
      menu.items
        .select { |item| item.enterprise_feature.present? }
        .each do |item|
          feature = item.enterprise_feature
          menu.add_condition(item.name, ->(*) { EnterpriseToken.allows_to?(feature) })
        end
    end

    def customize_global_menu(menu)
      configure_my_tasks(menu.find(:work_packages))
      rename(menu, :calendar_view, :"sparkfaktory.menu.calendar")
      rename(menu, :meetings, :"sparkfaktory.menu.meetings")
      rename(menu, :wikis, :"sparkfaktory.menu.documentation")

      menu.push :administration,
                { controller: "/admin", action: "index" },
                caption: :label_administration,
                icon: "gear",
                if: ->(*) { User.current.admin? }

      menu.reorder(GLOBAL_ORDER)
    end

    def customize_top_menu(menu)
      configure_my_tasks(menu.find(:work_packages))
      rename(menu, :calendar_view, :"sparkfaktory.menu.calendar")
      rename(menu, :meetings, :"sparkfaktory.menu.meetings")
      rename(menu, :wikis, :"sparkfaktory.menu.documentation")
    end

    def configure_my_tasks(item)
      return unless item

      item.caption = :"sparkfaktory.menu.my_tasks"
      item.url = OpenProject::Sparkfaktory::TaskQueries.path_params(:my_tasks)
    end

    def rename(menu, name, caption)
      menu.find(name)&.caption = caption
    end
  end
end
