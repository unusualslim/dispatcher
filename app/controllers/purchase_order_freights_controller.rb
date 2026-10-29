# The freight card on a purchase order: amount, how it's spread over the lines, who bills it (the vendor or a
# separate carrier, with invoice number, date and BOL), and whether it's an accrued estimate.
class PurchaseOrderFreightsController < ApplicationController
  permission_area :purchasing
  before_action :set_purchase_order

  def update
    PurchaseOrder.transaction do
      @purchase_order.assign_attributes(freight_params)
      apply_invoice!
      save_freight!
      save_invoice!
    end
    redirect_to purchase_order_path(@purchase_order, anchor: 'freight'), notice: t('.saved')
  rescue ActiveRecord::RecordInvalid => e
    redirect_to purchase_order_path(@purchase_order, anchor: 'freight'),
                alert: e.record.errors.full_messages.to_sentence
  end

  private

  def set_purchase_order
    @purchase_order = PurchaseOrder.find(params[:purchase_order_id])
  end

  # The carrier's actual invoice replaces the accrued estimate in landed cost while the PO isn't posted yet;
  # once posted, the estimate stays in inventory and the difference shows as a variance on the payable.
  def apply_invoice!
    return unless invoice_params[:amount].present? && invoice_params[:invoice_no].present? && !@purchase_order.posted?

    @purchase_order.freight_amount = invoice_params[:amount]
    @purchase_order.freight_accrued = false
  end

  # PDI history can fail unrelated validations (freight terms), so only the freight fields are checked.
  def save_freight!
    @purchase_order.validate
    @purchase_order.errors.delete(:freight_terms) # payment terms, checked on the PO form
    raise ActiveRecord::RecordInvalid, @purchase_order if @purchase_order.errors.any? { |e| freight_error?(e) }

    @purchase_order.save!(validate: false)
    @purchase_order.sync_freight_payable!
  end

  def freight_error?(error) = error.attribute.to_s.start_with?('freight_')

  def save_invoice!
    payable = @purchase_order.freight_payable
    payable.update!(invoice_params) if payable && invoice_params.values.any?(&:present?)
  end

  def freight_params
    params.require(:purchase_order).permit(:freight_amount, :freight_allocation, :freight_source, :freight_vendor_id,
                                           :freight_bol, :freight_accrued)
  end

  def invoice_params
    params.fetch(:freight_invoice, {}).permit(:invoice_no, :invoice_date, :amount)
  end
end
