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
    class WorkSummary < Grids::WidgetComponent
      UPCOMING_LIMIT = 6

      Counter = Data.define(:key, :count)

      def title
        I18n.t("sparkfaktory.home.work_summary.title")
      end

      def render?
        current_user.logged?
      end

      def counters
        [
          Counter.new(:my_tasks, mine.count),
          Counter.new(:my_overdue, overdue(mine).count),
          Counter.new(:blocked, blocked.count),
          Counter.new(:due_soon, due_soon.count)
        ]
      end

      def upcoming
        @upcoming ||= due_soon
          .or(overdue(visible_open))
          .includes(:project, :status, :assigned_to)
          .reorder(:due_date, :id)
          .limit(UPCOMING_LIMIT)
          .to_a
      end

      def counter_path(key)
        helpers.url_for(OpenProject::Sparkfaktory::TaskQueries.path_params(key).merge(only_path: true))
      end

      def due_label(work_package)
        if work_package.due_date < Date.current
          I18n.t("sparkfaktory.home.work_summary.overdue_since", date: helpers.format_date(work_package.due_date))
        else
          helpers.format_date(work_package.due_date)
        end
      end

      private

      def visible_open
        WorkPackage.visible(current_user).with_status_open
      end

      def mine
        visible_open.where(assigned_to_id: [current_user.id, *current_user.group_ids])
      end

      def overdue(scope)
        scope.where(due_date: ...Date.current)
      end

      def due_soon
        visible_open.where(due_date: Date.current..(Date.current + OpenProject::Sparkfaktory::TaskQueries::DUE_SOON_DAYS))
      end

      def blocked
        WorkPackage.visible(current_user).where(status_id: OpenProject::Sparkfaktory::TaskQueries.blocked_status_ids)
      end
    end
  end
end
