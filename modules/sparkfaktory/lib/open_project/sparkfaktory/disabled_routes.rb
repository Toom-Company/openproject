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
  # Instance-level pages of excluded features are guarded by `admin?` only, so module
  # permissions do not cover them. They answer 404 for everyone, including direct URLs.
  class DisabledRoutes
    PATTERNS = [
      %r{\A/admin/backlogs(/|\z)},
      %r{\A/admin/cost_types(/|\z)},
      %r{\A/admin/costs(/|\z)},
      %r{\A/admin/enterprise_trial(/|\z)},
      %r{\A/admin/settings/project_phase_definitions(/|\z)},
      %r{\A/admin/settings/storages(/|\z)},
      %r{\A/admin/settings/time_entry_activities(/|\z)},
      %r{\A/admin/settings/webhooks(/|\z)},
      %r{\A/api/bcf(/|\z)},
      %r{\A/cost_reports(/|\z)},
      %r{\A/cost_types(/|\z)},
      %r{\A/gantt(/|\z)},
      %r{\A/github_integration/admin(/|\z)},
      %r{\A/gitlab_integration/admin(/|\z)},
      %r{\A/my/time-tracking(/|\z)},
      %r{\A/news(/|\z)},
      %r{\A/notifications/share_upsell(/|\z)},
      %r{\A/portfolios(/|\z)},
      %r{\A/programs(/|\z)},
      %r{\A/project_phases(/|\z)},
      %r{\A/team_planners(/|\z)},
      %r{\A/projects/[^/]+/creation_wizard(/|\z)},
      %r{\A/projects/[^/]+/gantt(/|\z)},
      %r{\A/projects/[^/]+/project_life_cycle_sidebar(/|\z)},
      %r{\A/projects/[^/]+/roadmap(/|\z)}
    ].freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      return @app.call(env) unless self.class.disabled?(env["PATH_INFO"])

      [404, { "content-type" => "text/plain; charset=utf-8" }, ["Not Found"]]
    end

    def self.disabled?(path)
      return false if path.blank? || ENV["SPARKFAKTORY_DISABLE_ROUTE_GUARD"] == "true"

      PATTERNS.any? { |pattern| pattern.match?(path) }
    end
  end
end
