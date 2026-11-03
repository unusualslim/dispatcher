# Equipment details from the "Five Points Assets (Project Data)" sheet.
class AddEquipmentDetailsToThings < ActiveRecord::Migration[7.2]
  def change
    change_table :things, bulk: true do |t|
      t.string :serial_number
      t.string :production_line   # the line or project it belongs to, e.g. "South-Oil-Gallon Line"
      t.string :install_status    # Complete / In Progress
      t.string :power             # power requirements, e.g. "220V 3 phase"
      t.string :purchased_from
      t.string :invoice_number
      t.integer :year_made
    end
  end
end
