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

module OpenProject::Sparkfaktory
  # Cloudflare's email obfuscation decodes addresses with a script that only runs on full
  # page loads, so pages rendered by Turbo show "[email protected]". The markers make
  # Cloudflare leave HTML responses untouched.
  class EmailObfuscationOptOut
    OPEN = "<!--email_off-->".freeze
    CLOSE = "<!--/email_off-->".freeze
    BODY_OPEN = /<body\b[^>]*>/i
    BODY_CLOSE = %r{</body>}i

    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)
      return [status, headers, body] unless html?(headers)

      html = +""
      body.each { |chunk| html << chunk }
      body.close if body.respond_to?(:close)

      html = self.class.wrap(html)
      headers["content-length"] = html.bytesize.to_s if headers.key?("content-length")
      [status, headers, [html]]
    end

    def self.wrap(html)
      return html if html.include?(OPEN)

      body_open = BODY_OPEN.match(html)
      body_close = html.rindex(BODY_CLOSE)
      return "#{OPEN}#{html}#{CLOSE}" unless body_open && body_close && body_close > body_open.end(0)

      html.dup.insert(body_close, CLOSE).insert(body_open.end(0), OPEN)
    end

    private

    def html?(headers)
      content_type = headers["content-type"].to_s
      content_type.start_with?("text/html", "text/vnd.turbo-stream.html")
    end
  end
end
