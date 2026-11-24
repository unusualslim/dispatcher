# Purchasing → Suggested POs (SuggestedPurchases): MRP shortages and items at or below min, by vendor. A buyer ticks
# lines, adjusts quantities and creates draft POs, which still go through approval before anything is sent.
class SuggestedPurchasesController < ApplicationController
  include TickedRows

  permission_area :purchasing, features: { create: :inventory_pos }

  PICK_FIELDS = %i[product_id location_id vendor_id quantity unit_cost vendor_part_number need_date].freeze

  def index
    @lines = SuggestedPurchases.new.lines
    @lines = @lines.select { |l| l.location.nil? || l.location.id == current_warehouse.id } if current_warehouse
    @vendors = Vendor.order(:name) if @lines.any? { |l| l.vendor.nil? }
  end

  def create
    pos = SuggestedPurchases.create_pos!(ticked(:lines, PICK_FIELDS), user: current_user)
    return redirect_to(suggested_purchases_path, alert: t('.nothing')) if pos.empty?

    redirect_to purchase_orders_path, notice: t('.created', count: pos.size, numbers: pos.map(&:id).join(', '))
  end
end
