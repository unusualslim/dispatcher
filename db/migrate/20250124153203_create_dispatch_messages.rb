class CreateDispatchMessages < ActiveRecord::Migration[7.0]
  def change
    create_table :dispatch_messages do |t|
      t.references :user, null: false, foreign_key: true 
      t.text :message_body, null: false                
      t.string :delivery_method, null: false         
      t.datetime :sent_at                          
      t.string :status, default: "pending"             
      t.string :reference_id   
      t.timestamps
    end
  end
end