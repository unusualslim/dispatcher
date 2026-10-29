# Purchasing → Freight Payables: what we owe carriers, from POs with a separate carrier and the carrier cost on
# customer orders. Entering the carrier's invoice number and amount moves one from accrued to invoiced.
class FreightPayablesController < ApplicationController
  permission_area :purchasing
  FILTERS = %w[accrued invoiced all].freeze

  def index
    @filter = FILTERS.include?(params[:status]) ? params[:status] : 'accrued'
    @payables = filtered.paginate(page: params[:page], per_page: 50)
    @totals = FreightPayable.group(:status).sum('COALESCE(amount, accrued_amount)')
    @vendors = Vendor.where(id: FreightPayable.select(:vendor_id)).order(:name)
  end

  def update
    payable = FreightPayable.find(params[:id])
    if payable.update(payable_params)
      redirect_back_or_to freight_payables_path, notice: t('.updated', vendor: payable.vendor.name)
    else
      redirect_back_or_to freight_payables_path, alert: payable.errors.full_messages.to_sentence
    end
  end

  private

  def filtered
    scope = FreightPayable.includes(:vendor, :source).order(created_at: :desc)
    scope = scope.where(status: @filter) unless @filter == 'all'
    params[:vendor_id].present? ? scope.where(vendor_id: params[:vendor_id]) : scope
  end

  def payable_params
    params.require(:freight_payable).permit(:invoice_no, :invoice_date, :amount, :bol_number, :notes)
  end
end
