class AddCategoryToThingsAndAssociateWithDispatch < ActiveRecord::Migration[7.0]
  def change
    add_column :things, :category, :string, null: false, default: "truck" # Default to "truck"
    add_reference :things, :dispatch, foreign_key: true
  end
end
