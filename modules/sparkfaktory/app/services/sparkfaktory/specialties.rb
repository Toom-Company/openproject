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
  module Specialties
    module_function

    DEFAULT_OPTIONS = %w[backend frontend design].freeze

    def name
      I18n.t("sparkfaktory.specialties.name", locale: Setting.default_language.presence || "es")
    end

    def field
      UserCustomField.find_by(id: Setting.plugin_openproject_sparkfaktory.to_h["specialty_field_id"])
    end

    def for(user, field = self.field)
      return [] unless field && user.is_a?(User)

      Array(user.typed_custom_value_for(field)).map(&:to_s).compact_blank
    end
  end
end
