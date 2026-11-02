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
  # Work package list views built on the standard query props format
  # (see WorkPackages::DefaultQueryGeneratorService).
  module TaskQueries
    module_function

    DUE_SOON_DAYS = 7
    COLUMNS = %w[id subject project status priority assignee dueDate].freeze
    OPEN = { "n" => "status", "o" => "o", "v" => [] }.freeze

    SIDEBAR_KEYS = %i[my_tasks unassigned due_soon blocked].freeze

    def props(key)
      case key
      when :my_tasks
        base(group_by: "project", filters: [OPEN, { "n" => "assigneeOrGroup", "o" => "=", "v" => ["me"] }])
      when :my_overdue
        base(filters: [OPEN, { "n" => "assigneeOrGroup", "o" => "=", "v" => ["me"] }, overdue])
      when :unassigned
        base(group_by: "project", filters: [OPEN, { "n" => "assignee", "o" => "!*", "v" => [] }])
      when :overdue
        base(group_by: "project", filters: [OPEN, overdue])
      when :due_soon
        base(sort: "dueDate:asc,id:asc",
             filters: [OPEN, { "n" => "dueDate", "o" => "<>d",
                               "v" => [Date.current.iso8601, (Date.current + DUE_SOON_DAYS).iso8601] }])
      when :blocked
        base(group_by: "project", filters: [{ "n" => "status", "o" => "=", "v" => blocked_status_ids.map(&:to_s) }])
      end
    end

    def path_params(key)
      { controller: "/work_packages", action: "index", name: key, query_props: props(key).to_json }
    end

    def available?(key)
      key != :blocked || blocked_status_ids.any?
    end

    def blocked_status_ids
      Status.where(id: Setting.plugin_openproject_sparkfaktory["blocked_status_id"]).pluck(:id)
    end

    def overdue
      { "n" => "dueDate", "o" => "<t-", "v" => ["1"] }
    end

    def base(filters:, group_by: "", sort: "dueDate:asc,id:asc")
      { c: COLUMNS, hi: false, g: group_by, t: sort, f: filters }
    end
  end
end
