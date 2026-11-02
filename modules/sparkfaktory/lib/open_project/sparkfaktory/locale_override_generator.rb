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

require "yaml"

module OpenProject::Sparkfaktory
  # Builds config/locales/overrides/es.yml from the Spanish Crowdin files, replacing
  # "paquete(s) de trabajo" by "tarea(s)" and fixing the grammatical gender of the
  # determiners and of the most common adjectives that follow. Regenerate after
  # upgrading OpenProject: `rake sparkfaktory:generate_locale_overrides`.
  class LocaleOverrideGenerator
    NOUN = /paquete(s?) de trabajo/i

    PHRASES = {
      "todos los paquetes de trabajo" => "todas las tareas",
      "los paquetes de trabajo" => "las tareas",
      "estos paquetes de trabajo" => "estas tareas",
      "esos paquetes de trabajo" => "esas tareas",
      "otros paquetes de trabajo" => "otras tareas",
      "varios paquetes de trabajo" => "varias tareas",
      "algunos paquetes de trabajo" => "algunas tareas",
      "muchos paquetes de trabajo" => "muchas tareas",
      "nuevos paquetes de trabajo" => "nuevas tareas",
      "unos paquetes de trabajo" => "unas tareas",
      "del paquete de trabajo" => "de la tarea",
      "al paquete de trabajo" => "a la tarea",
      "el paquete de trabajo" => "la tarea",
      "un paquete de trabajo" => "una tarea",
      "este paquete de trabajo" => "esta tarea",
      "ese paquete de trabajo" => "esa tarea",
      "nuevo paquete de trabajo" => "nueva tarea",
      "ningún paquete de trabajo" => "ninguna tarea",
      "algún paquete de trabajo" => "alguna tarea",
      "primer paquete de trabajo" => "primera tarea",
      "único paquete de trabajo" => "única tarea",
      "propio paquete de trabajo" => "propia tarea",
      "otro paquete de trabajo" => "otra tarea",
      "mismo paquete de trabajo" => "misma tarea",
      "Paquetes de Trabajo" => "Tareas",
      "Paquete de Trabajo" => "Tarea",
      "paquetes de trabajo" => "tareas",
      "paquete de trabajo" => "tarea"
    }.freeze

    ADJECTIVES = %w[
      abierto actualizado archivado asignado bloqueado cerrado compartido copiado creado duplicado
      eliminado guardado modificado movido nuevo observado padre relacionado seleccionado vinculado
      afectado programado completado secundario insertado específico hijo
    ].freeze

    def initialize(root: Rails.root, output: Engine.root.join("config/locales/overrides/es.yml"))
      @root = Pathname(root)
      @output = Pathname(output)
    end

    def write!
      overrides = source_files.each_with_object({}) do |file, result|
        collect(YAML.safe_load_file(file, aliases: true, permitted_classes: [Symbol])&.dig("es") || {}, result)
      end

      @output.dirname.mkpath
      @output.write(header + { "es" => overrides }.to_yaml(line_width: -1))
      overrides
    end

    def convert(text)
      PHRASES.reduce(text) do |result, (from, to)|
        result
          .gsub(from, to)
          .gsub(capitalize(from), capitalize(to))
          .gsub(from.upcase, to.upcase)
      end.then { |result| fix_adjectives(result) }
    end

    private

    def source_files
      @root.glob("{config,modules/*/config}/locales/crowdin/{es,js-es,es.seeders}.yml").sort
    end

    def collect(tree, result)
      tree.each do |key, value|
        case value
        when Hash
          nested = collect(value, result[key].is_a?(Hash) ? result[key] : {})
          result[key] = nested if nested.any?
        when String
          result[key] = convert(value) if value.match?(NOUN)
        end
      end
      result
    end

    def fix_adjectives(text)
      text.gsub(/\b(tarea|Tarea)(s?) (#{ADJECTIVES.join('|')})(s?)\b/) do
        noun, plural, adjective, adjective_plural = Regexp.last_match.captures
        feminine = adjective == "padre" ? adjective : adjective.sub(/o\z/, "a")
        "#{noun}#{plural} #{feminine}#{adjective_plural}"
      end
    end

    def capitalize(text)
      text[0].upcase + text[1..]
    end

    def header
      "# Generated by `rake sparkfaktory:generate_locale_overrides`. Do not edit by hand.\n"
    end
  end
end
