class AddAssetReferencesToDispatches < ActiveRecord::Migration[7.0]
  def change
    add_reference :dispatches, :asset, foreign_key: true
  end
end
