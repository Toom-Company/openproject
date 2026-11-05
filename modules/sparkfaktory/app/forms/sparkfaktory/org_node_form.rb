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
  class OrgNodeForm < ApplicationForm
    form do |f|
      f.select_list(name: :principal_id, label: I18n.t("sparkfaktory.team.form.principal"),
                    caption: I18n.t("sparkfaktory.team.form.principal_caption"),
                    required: true, include_blank: true, input_width: :large) do |select|
        principal_options.each { |label, value| select.option(label:, value:) }
      end

      f.text_field(name: :title, label: I18n.t("sparkfaktory.team.form.title"),
                   caption: I18n.t("sparkfaktory.team.form.title_caption"), input_width: :large)

      f.select_list(name: :parent_id, label: I18n.t("sparkfaktory.team.form.parent"),
                    include_blank: I18n.t("sparkfaktory.team.form.no_parent"), input_width: :large) do |select|
        parent_options.each { |label, value| select.option(label:, value:) }
      end

      f.text_field(name: :position, label: I18n.t("sparkfaktory.team.form.position"), type: :number,
                   min: 0, input_width: :xsmall)

      f.submit(name: :submit, label: I18n.t(:button_save), scheme: :primary)
    end

    private

    def principal_options
      group_options + user_options
    end

    def group_options
      prefix = I18n.t("sparkfaktory.team.team_prefix")
      Group.order(:lastname).map { |group| ["#{prefix}: #{group.name}", group.id] }
    end

    def user_options
      User.active.where(type: "User").where.not(id: taken_principal_ids)
          .order(:firstname, :lastname).map { |user| [user.name, user.id] }
    end

    def taken_principal_ids
      Sparkfaktory::OrgNode.where.not(id: model.id).select(:principal_id)
    end

    def parent_options
      Sparkfaktory::OrgNode.includes(:principal).where.not(id: own_subtree_ids)
                           .map { |node| [node_label(node), node.id] }
                           .sort_by(&:first)
    end

    def own_subtree_ids
      model.persisted? ? [model.id, *model.descendant_ids] : []
    end

    def node_label(node)
      [node.title.presence, node.principal.name].compact.join(" — ")
    end
  end
end
