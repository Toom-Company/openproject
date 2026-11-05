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

module Sparkfaktory
  class RoleSummary
    PERMISSIONS = %i[
      add_work_packages edit_work_packages assign_work_packages delete_work_packages move_work_packages
      manage_work_package_relations manage_subtasks show_board_views manage_board_views
      create_meetings edit_project manage_members archive_project
    ].freeze

    Cell = Data.define(:status, :origins, :everywhere) do
      def allowed? = origins.any?
    end

    ROLE_KEYS = %w[boss leader member].freeze

    def roles
      @roles ||= ProjectRole.givable.where(builtin: Role::NON_BUILTIN).order(:position).to_a
                            .sort_by { |role| [ROLE_KEYS.index(key_for(role)) || ROLE_KEYS.size, role.position] }
    end

    def description(role)
      key = key_for(role)
      I18n.t("sparkfaktory.team.roles.descriptions.#{key}") if key
    end

    def statuses
      @statuses ||= Status.order_by_position.to_a
    end

    def type
      @type ||= Type.order(:position).first
    end

    def permissions
      @permissions ||= PERMISSIONS.select { |name| OpenProject::AccessControl.permission(name) }
    end

    def allowed?(role, permission)
      role.permissions.include?(permission)
    end

    def transitions(role)
      statuses.map do |target|
        origins = statuses.select { |from| from != target && transition_pairs(role).include?([from.id, target.id]) }
        Cell.new(status: target, origins:, everywhere: origins.size == statuses.size - 1)
      end
    end

    private

    def key_for(role)
      ROLE_KEYS.find { |key| plugin_settings["#{key}_role_id"].to_i == role.id }
    end

    def plugin_settings
      @plugin_settings ||= Setting.plugin_openproject_sparkfaktory.to_h
    end

    def transition_pairs(role)
      @transition_pairs ||= workflows.group_by(&:role_id)
                                     .transform_values { |rows| rows.to_set { [it.old_status_id, it.new_status_id] } }
      @transition_pairs.fetch(role.id, Set.new)
    end

    def workflows
      variant = type&.default_variant
      return Workflow.none unless variant

      variant.workflows.where(author: false, assignee: false)
    end
  end
end
