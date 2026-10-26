class AddPdiCreditToCustomers < ActiveRecord::Migration[7.2]
  def change
    change_table :customers, bulk: true do |t|
      t.string :pdi_credit_status
      t.decimal :pdi_credit_limit, precision: 12, scale: 2
      t.decimal :pdi_available_credit, precision: 12, scale: 2
      t.datetime :pdi_credit_updated_at
    end
  end
end
