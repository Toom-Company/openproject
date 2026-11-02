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
  # Spanish wording ("Tareas" instead of "Paquetes de trabajo", ...) must win over every
  # Crowdin file, so the override files are kept at the end of the load path.
  module LocaleOverrides
    module_function

    def files
      Engine.root.glob("config/locales/overrides/*.yml").map(&:to_s).sort
    end

    def load!
      overrides = files
      current = I18n.load_path.map(&:to_s)
      return if overrides.empty? || current.last(overrides.size) == overrides

      I18n.load_path = current.reject { |path| overrides.include?(path) } + overrides
      I18n.reload!
    end
  end
end
