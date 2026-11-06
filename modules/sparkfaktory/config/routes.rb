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

Rails.application.routes.draw do
  scope "equipo" do
    get "/", to: "sparkfaktory/team#show", as: :sparkfaktory_team
    get "roles", to: "sparkfaktory/team#roles", as: :sparkfaktory_team_roles
    resources :org_nodes, path: "organigrama", controller: "sparkfaktory/org_nodes",
                          as: :sparkfaktory_org_nodes, only: %i[new create edit update destroy]
    resources :specialties, path: "especialidades", controller: "sparkfaktory/specialties", param: :user_id,
                            as: :sparkfaktory_specialties, only: %i[index edit update]
  end
end
