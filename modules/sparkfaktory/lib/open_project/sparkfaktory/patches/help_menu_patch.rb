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

module OpenProject::Sparkfaktory::Patches
  # Keeps documentation links and drops the sales, newsletter and video entries.
  module HelpMenuPatch
    def render_help_dropdown
      render Primer::Alpha::ActionMenu.new(classes: "op-app-menu--item",
                                           menu_id: "op-app-header--help-menu",
                                           pl: 1,
                                           anchor_align: :end) do |menu|
        menu.with_show_button(icon: :question,
                              scheme: :invisible,
                              classes: "op-app-header--primer-button",
                              test_selector: "header-help-button",
                              "aria-label": I18n.t(:label_help))

        menu.with_group do |group|
          group.with_heading(title: I18n.t("top_menu.help_and_support"))
          %i[user_guides shortcuts api_docs].each { |key| group.with_item(**link_options_for(key)) }
        end
      end
    end
  end
end
