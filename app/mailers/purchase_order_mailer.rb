# A purchase order's vendor copy, emailed from the PO page; replies go to the person who sent it.
class PurchaseOrderMailer < ApplicationMailer
  default from: 'no-reply@fivepointsservice.com'

  def vendor_copy(purchase_order, to:, sender:, message: nil)
    @purchase_order = purchase_order
    @emailed = true
    @email_message = message.presence
    company = AppSetting.company['name'].presence || 'Five Points Service'
    mail(to: to, cc: sender.email, reply_to: sender.email,
         subject: "Purchase Order #{purchase_order.display_number} from #{company}") do |format|
      format.html { render 'purchase_orders/print', layout: false }
    end
  end
end
