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

namespace :sparkfaktory do
  desc "Apply the Sparkfaktory Proyectos instance configuration (FORCE=true rewrites the settings)"
  task setup: :environment do
    Sparkfaktory::InstanceSetupService.new(force: ENV["FORCE"] == "true").call
    puts "Sparkfaktory setup applied."
  end

  desc "Regenerate the Spanish wording overrides (Tareas instead of Paquetes de trabajo)"
  task generate_locale_overrides: :environment do
    OpenProject::Sparkfaktory::LocaleOverrideGenerator.new.write!
  end
end

namespace :sparkfaktory do
  desc "Create administrators from SPARKFAKTORY_ADMIN_EMAILS (comma separated). RESET=true sets new temporary passwords"
  task create_admins: :environment do
    emails = ENV.fetch("SPARKFAKTORY_ADMIN_EMAILS", "").split(/[\s,;]+/)
    abort "SPARKFAKTORY_ADMIN_EMAILS is empty" if emails.empty?

    accounts = Sparkfaktory::AdminAccountsService.new(emails:, reset_passwords: ENV["RESET"] == "true").call.result
    accounts.each do |account|
      password = account.password || "(sin cambios)"
      puts format("%-40<mail>s %-10<state>s %<password>s", mail: account.mail,
                                                          state: account.created ? "creada" : "existente", password:)
    end
    puts "Las claves temporales se muestran una sola vez y deben cambiarse en el primer acceso."
  end
end
