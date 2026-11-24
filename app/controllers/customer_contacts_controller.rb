# Customer contacts on the customer page: PDI's contacts arrive with master data; here someone ticks who gets
# invoices and statements, and adds contacts PDI doesn't have.
class CustomerContactsController < ApplicationController
  permission_area :sales, feature: :customers
  before_action :set_customer

  def create
    contact = @customer.customer_contacts.new(contact_params.merge(source: 'app'))
    if contact.save
      redirect_to customer_path(@customer, anchor: 'contacts'), notice: t('.added', name: contact.label)
    else
      redirect_to customer_path(@customer, anchor: 'contacts'), alert: contact.errors.full_messages.to_sentence
    end
  end

  # Only the invoice tick (and, for app contacts, active) changes here; PDI contacts are kept by the sync.
  def update
    contact = @customer.customer_contacts.find(params[:id])
    contact.update!(invoice_recipient: params[:invoice_recipient] == '1')
    redirect_to customer_path(@customer, anchor: 'contacts'),
                notice: t(contact.invoice_recipient ? '.invoice_on' : '.invoice_off', name: contact.label)
  end

  def destroy
    @customer.customer_contacts.where(source: 'app').find(params[:id]).destroy!
    redirect_to customer_path(@customer, anchor: 'contacts'), notice: t('.removed')
  end

  private

  def set_customer
    @customer = Customer.find(params[:customer_id])
  end

  def contact_params
    params.permit(:first_name, :last_name, :email, :phone, :invoice_recipient).to_h.symbolize_keys
          .then { |attrs| attrs.merge(invoice_recipient: attrs[:invoice_recipient] == '1') }
  end
end
