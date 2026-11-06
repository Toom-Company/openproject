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
  class SpecialtiesController < ApplicationController
    include Layout

    before_action :require_login
    before_action :require_admin, only: %i[edit update]
    before_action :find_field
    before_action :find_user, only: %i[edit update]
    no_authorization_required! :index

    menu_item :sparkfaktory_team

    def index
      @users = User.active.where(type: "User").order(:firstname, :lastname).to_a
      @nodes = Sparkfaktory::OrgNode.where(principal_id: @users.map(&:id)).index_by(&:principal_id)
      render locals: { menu_name: :global_menu }
    end

    def edit
      render locals: { menu_name: :global_menu }
    end

    def update
      result = save_specialties
      save_job_title

      if result.success?
        redirect_to sparkfaktory_specialties_path, notice: I18n.t(:notice_successful_update)
      else
        flash.now[:error] = result.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_entity, locals: { menu_name: :global_menu }
      end
    end

    private

    def find_field
      @field = Sparkfaktory::Specialties.field
      render_404 unless @field
    end

    def find_user
      @user = User.where(type: "User").find(params.expect(:user_id))
      @node = Sparkfaktory::OrgNode.find_by(principal: @user)
    end

    def save_specialties
      Users::UpdateService.new(model: @user, user: current_user)
                          .call(custom_field_values: { @field.id.to_s => selected_option_ids })
    end

    def save_job_title
      @node.update!(title: params[:title].to_s.strip) if @node && params.key?(:title)
    end

    def selected_option_ids
      Array(params[:specialty_ids]).map(&:to_s) & @field.custom_options.map { it.id.to_s }
    end
  end
end
