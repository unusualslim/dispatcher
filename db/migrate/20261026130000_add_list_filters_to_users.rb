class AddListFiltersToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :list_filters, :jsonb, default: {}, null: false
  end
end
