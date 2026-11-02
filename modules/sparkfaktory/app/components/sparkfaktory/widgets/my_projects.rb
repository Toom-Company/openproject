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
    class MyProjects < Grids::WidgetComponent
      include ProjectsHelper

      LIMIT = 8

      def title
        I18n.t("sparkfaktory.home.projects.title")
      end

      def render?
        current_user.logged?
      end

      def projects
        @projects ||= accessible.order(updated_at: :desc).limit(LIMIT).to_a
      end

      def total
        @total ||= accessible.count
      end

      def can_create?
        current_user.allowed_globally?(:add_project)
      end

      private

      def accessible
        Project.visible(current_user).active.where(workspace_type: "project", templated: false)
      end
    end
  end
end
