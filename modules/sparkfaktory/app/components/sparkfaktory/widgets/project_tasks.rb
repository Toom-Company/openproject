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
  module Widgets
    class ProjectTasks < Grids::WidgetComponent
      ASSIGNEE_LIMIT = 6
      UPCOMING_LIMIT = 5

      param :project

      def title
        I18n.t("sparkfaktory.project_overview.tasks.title")
      end

      def render?
        current_user.allowed_in_project?(:view_work_packages, project)
      end

      def by_status
        counts = tasks.group(:status_id).count
        Status.where(id: counts.keys).order(:position).map { |status| [status, counts[status.id]] }
      end

      def by_assignee
        counts = tasks.with_status_open.group(:assigned_to_id).count
        principals = Principal.where(id: counts.keys.compact).index_by(&:id)
        counts.sort_by { |_, count| -count }.first(ASSIGNEE_LIMIT).map { |id, count| [principals[id], count] }
      end

      def overdue_count
        tasks.with_status_open.where(due_date: ...Date.current).count
      end

      def upcoming
        tasks.with_status_open
             .where.not(due_date: nil)
             .includes(:status, :assigned_to)
             .reorder(:due_date, :id)
             .limit(UPCOMING_LIMIT)
             .to_a
      end

      def status_path(status)
        list_path(f: [{ "n" => "status", "o" => "=", "v" => [status.id.to_s] }])
      end

      def assignee_path(principal)
        filter = principal ? { "n" => "assignee", "o" => "=", "v" => [principal.id.to_s] } : { "n" => "assignee", "o" => "!*", "v" => [] }
        list_path(f: [OpenProject::Sparkfaktory::TaskQueries::OPEN, filter])
      end

      def overdue_path
        list_path(f: [OpenProject::Sparkfaktory::TaskQueries::OPEN, OpenProject::Sparkfaktory::TaskQueries.overdue])
      end

      private

      def tasks
        WorkPackage.visible(current_user).where(project:)
      end

      def list_path(f:)
        props = OpenProject::Sparkfaktory::TaskQueries.base(filters: f).merge(c: %w[id subject status priority assignee dueDate])
        helpers.project_work_packages_path(project, query_props: props.to_json)
      end
    end
  end
end
