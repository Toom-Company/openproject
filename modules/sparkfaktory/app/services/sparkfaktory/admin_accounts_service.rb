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
  # Creates the named administrators with a random temporary password that must be
  # changed at first login, then locks the generic seeded "admin" account.
  class AdminAccountsService
    Account = Data.define(:mail, :login, :password, :created)

    def initialize(emails:, reset_passwords: false)
      @emails = Array(emails).map { |mail| mail.to_s.strip.downcase }.compact_blank.uniq
      @reset_passwords = reset_passwords
    end

    def call
      accounts = User.transaction do
        @emails.map { |mail| ensure_admin(mail) }.tap { lock_generic_admin }
      end

      ServiceResult.success(result: accounts)
    end

    private

    def ensure_admin(mail)
      user = User.find_by(mail:) || User.find_by(login: mail)
      return create_admin(mail) if user.nil?

      password = assign_temporary_password(user) if @reset_passwords
      user.update!(admin: true, status: :active)
      Account.new(mail:, login: user.login, password:, created: false)
    end

    def create_admin(mail)
      firstname, lastname = names_from(mail)
      user = User.new(login: mail, mail:, firstname:, lastname:, admin: true, status: :active, language: "es")
      password = assign_temporary_password(user)
      user.save!
      Account.new(mail:, login: user.login, password:, created: true)
    end

    def assign_temporary_password(user)
      password = temporary_password
      user.password = password
      user.password_confirmation = password
      user.force_password_change = true
      user.save! if user.persisted?
      password
    end

    def temporary_password
      "Sf#{SecureRandom.alphanumeric(14)}-#{SecureRandom.random_number(90) + 10}"
    end

    def names_from(mail)
      parts = mail.split("@").first.split(/[._-]+/).map(&:capitalize)
      [parts.first || mail, parts.drop(1).join(" ").presence || parts.first || mail]
    end

    def lock_generic_admin
      generic = User.find_by(login: "admin")
      return if generic.nil? || @emails.include?(generic.mail.to_s.downcase)
      return unless User.admin.active.where.not(id: generic.id).exists?

      generic.update!(status: :locked)
    end
  end
end
