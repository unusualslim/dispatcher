require 'test_helper'

# Customer page: bill-to address and contacts, with the invoice recipients ticked in the app.
class CustomerContactsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @customer = Customer.create!(name: 'Contact Co', pdi_customer_id: 'CC-1', bill_address1: 'PO Box 9',
                                 bill_city: 'Albany', bill_state: 'GA', bill_zip: '31701')
    @pdi = @customer.customer_contacts.create!(first_name: 'Pat', email: 'pat@cc.example', source: 'pdi')
  end

  test 'shows the bill-to and contacts; a sales editor ticks invoice recipients and adds a contact' do
    sign_in staff_user('cc-sales@example.com', { 'sales' => 'edit' })
    get customer_path(@customer)
    assert_select 'div', text: /PO Box 9.*Albany, GA 31701/m
    assert_select '#contacts td', text: 'Pat'

    patch customer_customer_contact_path(@customer, @pdi), params: { invoice_recipient: '1' }
    assert @pdi.reload.invoice_recipient

    post customer_customer_contacts_path(@customer),
         params: { first_name: 'Ann', email: 'ann@cc.example', invoice_recipient: '1' }
    assert_equal %w[ann@cc.example pat@cc.example], @customer.customer_contacts.invoice_recipients.pluck(:email).sort
  end

  test 'viewers cannot change contacts' do
    sign_in staff_user('cc-view@example.com', { 'sales' => 'view' })
    patch customer_customer_contact_path(@customer, @pdi), params: { invoice_recipient: '1' }
    assert_not @pdi.reload.invoice_recipient
  end
end
