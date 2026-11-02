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
  # Text wordmark instead of the OpenProject logo until an own logo is uploaded.
  module TopMenuHelperPatch
    def render_logo
      return super if custom_logo?

      content_tag :div, class: "op-logo sf-wordmark" do
        link_to(configurable_home_url, class: "sf-wordmark--link", title: I18n.t("label_home")) do
          wordmark_content
        end
      end
    end

    def render_logo_icon
      return super if custom_logo?

      link_to(configurable_home_url, class: "sf-wordmark sf-wordmark--compact", title: I18n.t("label_home")) do
        content_tag(:span, wordmark_initial, class: "sf-wordmark--initial", "aria-hidden": true) +
          content_tag(:span, Setting.app_title, class: "sr-only")
      end
    end

    private

    def wordmark_content
      first, rest = Setting.app_title.to_s.split(" ", 2)
      safe_join([content_tag(:span, first, class: "sf-wordmark--name"),
                 (content_tag(:span, rest, class: "sf-wordmark--product") if rest.present?)].compact)
    end

    def wordmark_initial
      Setting.app_title.to_s.strip.first&.upcase || "S"
    end
  end
end
