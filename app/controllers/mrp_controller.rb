class MrpController < ApplicationController
  before_action :require_admin!
  def index
    @requirements     = MrpEngine.new(horizon_days: 30).run
    @low_stock        = Product.raw_materials.where.not(reorder_point: nil)
                               .order(:current_stock)
    @draft_pos        = PurchaseOrder.includes(:vendor, line_items: :product).draft.order(created_at: :desc)
    @pending_pos      = PurchaseOrder.includes(:vendor, line_items: :product).pending_approval.order(created_at: :desc)
  end
end
