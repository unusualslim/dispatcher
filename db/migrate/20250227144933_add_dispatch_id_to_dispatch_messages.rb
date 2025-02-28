class AddDispatchIdToDispatchMessages < ActiveRecord::Migration[7.0]
  def change
    add_reference :dispatch_messages, :dispatch, foreign_key: true
  end
end
