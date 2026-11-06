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
  module Specialties
    module_function

    CATALOG = {
      software_development: [
        "Software Developer", "Software Engineer", "Web Developer", "Front-End Developer", "Back-End Developer",
        "Full-Stack Developer", "Mobile App Developer", "Game Developer", "Application Developer",
        "Embedded Software Developer"
      ],
      it_technology: [
        "IT Specialist", "IT Support Specialist", "Systems Administrator", "Cloud Engineer", "DevOps Engineer",
        "Cybersecurity Engineer", "Network Engineer", "Database Administrator", "Solutions Architect",
        "Technical Support Engineer"
      ],
      leadership_management: [
        "Software Architect", "Technical Lead", "Team Lead", "Engineering Manager", "CTO (Chief Technology Officer)",
        "IT Director", "Project Manager", "Product Manager", "Technical Program Manager", "Head of Engineering"
      ],
      data_ai: [
        "Data Scientist", "Data Engineer", "Data Analyst", "Machine Learning Engineer", "AI Engineer",
        "AI Research Scientist", "Business Intelligence Developer", "Big Data Engineer"
      ],
      testing_qa: [
        "QA Engineer", "Software Tester", "Automation Engineer", "Test Engineer", "QA Automation Engineer",
        "Performance Test Engineer", "Quality Assurance Analyst"
      ],
      ui_ux_design: [
        "UI Developer", "UX Designer", "UI/UX Designer", "Product Designer", "Interaction Designer", "Web Designer",
        "UX Researcher"
      ],
      emerging_technologies: [
        "Blockchain Developer", "Smart Contract Developer", "AR/VR Developer", "Robotics Engineer", "IoT Developer",
        "Computer Vision Engineer", "Generative AI Developer"
      ]
    }.freeze

    def titles
      CATALOG.values.flatten
    end

    def name
      I18n.t("sparkfaktory.specialties.name", locale: Setting.default_language.presence || "es")
    end

    def field
      UserCustomField.find_by(id: Setting.plugin_openproject_sparkfaktory.to_h["specialty_field_id"])
    end

    def for(user, field = self.field)
      return [] unless field && user.is_a?(User)

      Array(user.typed_custom_value_for(field)).map(&:to_s).compact_blank
    end

    def grouped(values)
      groups = CATALOG.filter_map do |key, titles|
        in_group = values.select { titles.include?(it.to_s) }
        [I18n.t("sparkfaktory.specialties.categories.#{key}"), in_group] if in_group.any?
      end
      others = values.reject { titles.include?(it.to_s) }
      groups << [I18n.t("sparkfaktory.specialties.categories.other"), others] if others.any?
      groups
    end

    # Matches options by value, so a value already assigned to someone is never renamed into another one.
    def sync_catalog!(field)
      options = field.custom_options.index_by(&:value)
      titles.each.with_index(1) do |title, position|
        (options.delete(title) || field.custom_options.build(value: title)).update!(position:)
      end
      keep_options_in_use(field, options.values)
    end

    def keep_options_in_use(field, options)
      in_use = CustomValue.where(custom_field: field, value: options.map { it.id.to_s }).pluck(:value)
      options.each.with_index(titles.size + 1) do |option, position|
        in_use.include?(option.id.to_s) ? option.update!(position:) : option.destroy!
      end
    end
  end
end
