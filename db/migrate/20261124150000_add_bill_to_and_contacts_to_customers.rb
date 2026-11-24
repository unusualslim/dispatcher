# Each customer's master (bill-to) address, printed on PDI's invoices and statements, and its contacts, both from
# PDI master data. Contacts have no role in PDI, so the invoice recipients are ticked in the app.
class AddBillToAndContactsToCustomers < ActiveRecord::Migration[8.1]
  BILL_TO = %i[bill_address1 bill_address2 bill_city bill_state bill_zip bill_county].freeze

  def change
    BILL_TO.each { |column| add_column :customers, column, :string }
    create_contacts
  end

  private

  def create_contacts
    create_table :customer_contacts do |t|
      t.references :customer, null: false, foreign_key: true
      %i[first_name last_name email phone].each { |column| t.string column }
      t.boolean :active, null: false, default: true
      t.boolean :invoice_recipient, null: false, default: false
      t.string :source, null: false, default: 'app'
      t.timestamps
    end
  end
end
