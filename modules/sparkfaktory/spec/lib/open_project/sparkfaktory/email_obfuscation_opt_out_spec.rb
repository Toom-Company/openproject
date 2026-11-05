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

require "spec_helper"

RSpec.describe OpenProject::Sparkfaktory::EmailObfuscationOptOut do
  def call(content_type, body)
    app = ->(_env) { [200, { "content-type" => content_type, "content-length" => body.bytesize.to_s }, [body]] }
    described_class.new(app).call({})
  end

  it "marks the body of full pages, keeping the doctype first" do
    _, headers, body = call("text/html; charset=utf-8",
                            "<!DOCTYPE html><html><body class=\"a\"><a>x@example.com</a></body></html>")

    expect(body.join).to eq("<!DOCTYPE html><html><body class=\"a\"><!--email_off--><a>x@example.com</a>" \
                            "<!--/email_off--></body></html>")
    expect(headers["content-length"]).to eq(body.join.bytesize.to_s)
  end

  it "wraps HTML fragments and turbo streams entirely" do
    _, _, body = call("text/vnd.turbo-stream.html", "<turbo-stream>x@example.com</turbo-stream>")

    expect(body.join).to eq("<!--email_off--><turbo-stream>x@example.com</turbo-stream><!--/email_off-->")
  end

  it "leaves other responses untouched" do
    _, _, body = call("application/json", '{"mail":"x@example.com"}')

    expect(body.join).to eq('{"mail":"x@example.com"}')
  end
end
