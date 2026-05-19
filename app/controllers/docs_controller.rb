require "redcarpet"

class DocsController < ApplicationController
  before_action :require_admin!
  def mrp_guide
    source = Rails.root.join("docs/mrp_user_guide.md").read
    renderer = Redcarpet::Render::HTML.new(tables: true, hard_wrap: true)
    markdown = Redcarpet::Markdown.new(renderer, tables: true, fenced_code_blocks: true, autolink: true)
    @content = markdown.render(source).html_safe
  end
end
