require "redcarpet"

class DocsController < ApplicationController
  before_action :require_admin!

  GUIDES = [
    {
      slug:        'dispatch',
      title:       'Dispatch & Orders',
      description: 'Customer orders, dispatch assignments, drivers, calendar, and map.',
      icon:        'bi-truck',
      color:       'primary',
      path:        '/docs/dispatch-guide'
    },
    {
      slug:        'manufacturing',
      title:       'Manufacturing',
      description: 'Production orders, batch management, QC workflow, and lot traceability.',
      icon:        'bi-gear',
      color:       'success',
      path:        '/docs/manufacturing'
    },
    {
      slug:        'mrp',
      title:       'Inventory & MRP',
      description: 'Products, BOM, purchase orders, stock adjustments, and MRP planning.',
      icon:        'bi-graph-up-arrow',
      color:       'warning',
      path:        '/docs/mrp-guide'
    }
  ].freeze

  def index
    @guides = GUIDES
  end

  def dispatch_guide
    render_guide('dispatch_guide.md')
  end

  def manufacturing
    render_guide('manufacturing_guide.md')
  end

  def mrp_guide
    render_guide('mrp_user_guide.md')
  end

  def changelog
  end

  private

  def render_guide(filename)
    source = Rails.root.join("docs/#{filename}").read
    @content = markdown.render(source).html_safe
    render :guide
  end

  def markdown
    renderer = Redcarpet::Render::HTML.new(tables: true, hard_wrap: true)
    Redcarpet::Markdown.new(renderer, tables: true, fenced_code_blocks: true, autolink: true)
  end
end
