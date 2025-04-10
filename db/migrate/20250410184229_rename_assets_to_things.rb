class RenameAssetsToThings < ActiveRecord::Migration[7.0]
  def change
    rename_table :assets, :things
  end
end
