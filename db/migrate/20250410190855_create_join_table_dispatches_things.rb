class CreateJoinTableDispatchesThings < ActiveRecord::Migration[7.0]
  def change
    create_join_table :dispatches, :things do |t|
      t.index :dispatch_id
      t.index :thing_id
    end
  end
end
