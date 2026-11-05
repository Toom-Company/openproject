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
  class OrgNodesController < ApplicationController
    include Layout

    before_action :require_admin
    before_action :find_node, only: %i[edit update destroy]

    menu_item :sparkfaktory_team

    def new
      @node = Sparkfaktory::OrgNode.new(parent_id: params[:parent_id], principal_id: params[:principal_id])
      render locals: { menu_name: :global_menu }
    end

    def edit
      render locals: { menu_name: :global_menu }
    end

    def create
      @node = Sparkfaktory::OrgNode.new(node_params)
      @node.position = Sparkfaktory::OrgNode.where(parent_id: @node.parent_id).maximum(:position).to_i + 1

      if @node.save
        redirect_to sparkfaktory_team_path, notice: I18n.t(:notice_successful_create)
      else
        render :new, status: :unprocessable_entity, locals: { menu_name: :global_menu }
      end
    end

    def update
      if @node.update(node_params)
        redirect_to sparkfaktory_team_path, notice: I18n.t(:notice_successful_update)
      else
        render :edit, status: :unprocessable_entity, locals: { menu_name: :global_menu }
      end
    end

    def destroy
      @node.destroy!
      redirect_to sparkfaktory_team_path, notice: I18n.t(:notice_successful_delete), status: :see_other
    end

    private

    def find_node
      @node = Sparkfaktory::OrgNode.find(params.expect(:id))
    end

    def node_params
      params.expect(org_node: %i[principal_id parent_id title position])
    end
  end
end
