require 'test_helper'

class PurchaseOrderMailerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActionMailer::TestHelper

  test 'the PO page emails the vendor copy, replies to the sender' do
    vendor = Vendor.create!(id: 'POM-V', name: 'Urea Co', email: 'orders@urea.example')
    po = PurchaseOrder.create!(vendor: vendor, pdi_reference: 'PO-77', status: 'approved')
    po.line_items.create!(product_name: 'Urea prills', quantity: 10, unit_cost: 400)
    user = User.create!(email: 'buyer@example.com', password: 'password123', role: 'admin')
    sign_in user

    get purchase_order_path(po)
    assert_select "input[name=to][value='orders@urea.example']"

    assert_enqueued_emails 1 do
      post email_vendor_purchase_order_path(po), params: { to: 'orders@urea.example', message: 'Ship Friday please' }
    end
    assert_redirected_to purchase_order_path(po)

    mail = PurchaseOrderMailer.vendor_copy(po, to: ['orders@urea.example'], sender: user, message: 'Ship Friday please')
    assert_equal ['buyer@example.com'], mail.reply_to
    assert_match 'PO-77', mail.subject
    assert_match 'Urea prills', mail.body.encoded
    assert_match 'Ship Friday please', mail.body.encoded
    assert_no_match 'window.print', mail.body.encoded
  end
end
