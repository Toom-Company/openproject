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
  # Idempotent instance configuration for Sparkfaktory Proyectos. Runs at the end of
  # `db:seed` and through `rake sparkfaktory:setup`. Settings are written only on the
  # first run (or with force: true) so later changes made by administrators survive.
  class InstanceSetupService
    VERSION = 1

    DEFAULT_PROJECT_MODULES = %w[work_package_tracking board_view calendar_view meetings activity].freeze

    LEADER_DENIED_PERMISSIONS = %i[
      archive_project
      manage_types
      manage_project_variants
      select_custom_fields
      select_project_custom_fields
      select_project_modules
    ].freeze

    def initialize(force: false)
      @force = force
    end

    def call
      ActiveRecord::Base.transaction do
        apply_settings if @force || plugin_settings["setup_version"].blank?
        setup_roles
        setup_project_custom_fields
        mark_template_projects
        remember_blocked_status
        store_plugin_settings("setup_version" => VERSION)
      end

      ServiceResult.success
    end

    private

    def apply_settings
      Setting.app_title = "Sparkfaktory Proyectos"
      Setting.default_language = "es"
      Setting.available_languages = (Array(Setting.available_languages) | %w[es en]).sort
      Setting.ee_hide_banners = true
      Setting.security_badge_displayed = false
      Setting.default_projects_modules = DEFAULT_PROJECT_MODULES & available_modules
      Setting.default_projects_public = false
      Setting.login_required = true
      Setting.self_registration = "0"
      Setting.start_of_week = 1
      disable_gravatar
    end

    def available_modules
      OpenProject::AccessControl.available_project_modules.map(&:to_s)
    end

    def disable_gravatar
      return unless Setting.respond_to?(:plugin_openproject_avatars)

      Setting.plugin_openproject_avatars = Setting.plugin_openproject_avatars.to_h.merge("enable_gravatars" => false)
    end

    def setup_roles
      admin_role&.update!(name: I18n.t("sparkfaktory.roles.admin", locale: seed_locale))
      member_role&.update!(name: I18n.t("sparkfaktory.roles.member", locale: seed_locale))
      leader = leader_role
      copy_workflows(from: admin_role, to: leader) if admin_role && leader.workflows.none?
      remove_unused_reader_role
    end

    def admin_role
      @admin_role ||= ProjectRole.find_by(id: Setting.new_project_user_role_id)
    end

    def member_role
      ProjectRole.givable.where(builtin: Role::NON_BUILTIN)
                 .find_by(name: [I18n.t("seeds.common.project_roles.item_2.name", locale: seed_locale, default: "Member"),
                                 "Member"])
    end

    def leader_role
      name = I18n.t("sparkfaktory.roles.leader", locale: seed_locale)
      ProjectRole.find_by(name:) || create_leader_role(name)
    end

    def create_leader_role(name)
      permissions = (admin_role&.permissions || []) - LEADER_DENIED_PERMISSIONS
      ProjectRole.create!(name:, permissions:, position: Role.maximum(:position).to_i + 1)
    end

    def copy_workflows(from:, to:)
      from.workflows.find_each do |workflow|
        to.workflows.create!(workflow.attributes.slice("type_variant_id", "old_status_id", "new_status_id",
                                                       "author", "assignee"))
      end
    end

    def remove_unused_reader_role
      reader_names = [I18n.t("seeds.common.project_roles.item_3.name", locale: seed_locale, default: "Reader"), "Reader"]
      ProjectRole.where(name: reader_names, builtin: Role::NON_BUILTIN)
                 .where.missing(:member_roles)
                 .destroy_all
    end

    def setup_project_custom_fields
      section = ProjectCustomFieldSection.order(:position).first ||
                ProjectCustomFieldSection.create!(name: I18n.t("seeds.sparkfaktory.project_custom_field_sections.item_0.name",
                                                               locale: seed_locale, default: "Project details"))
      %i[start_date end_date].each_with_index do |key, index|
        name = I18n.t("sparkfaktory.project_custom_fields.#{key}", locale: seed_locale)
        next if ProjectCustomField.exists?(name:)

        ProjectCustomField.create!(name:, field_format: "date", is_for_all: true, is_required: false,
                                   project_custom_field_section: section, position: index + 1)
      end
    end

    def mark_template_projects
      Project.where(identifier: "plantilla-proyecto", templated: false).find_each do |project|
        project.update_columns(templated: true)
      end
    end

    def remember_blocked_status
      return if Status.exists?(id: plugin_settings["blocked_status_id"])

      blocked = Status.find_by(name: [I18n.t("seeds.sparkfaktory.statuses.item_2.name", locale: seed_locale, default: "Blocked"),
                                      "Blocked", "Bloqueada"])
      store_plugin_settings("blocked_status_id" => blocked&.id)
    end

    def plugin_settings
      Setting.plugin_openproject_sparkfaktory.to_h
    end

    def store_plugin_settings(values)
      Setting.plugin_openproject_sparkfaktory = plugin_settings.merge(values)
    end

    def seed_locale
      ENV.fetch("OPENPROJECT_SEED_LOCALE", Setting.default_language).presence || "es"
    end
  end
end
