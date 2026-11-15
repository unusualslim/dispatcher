# things.dispatch_id was a retired link: a dispatch's truck and trailer are dispatches.truck_id / trailer_id.
# The app has ignored the column since 88e591c (deployed 2026-11-14), and all 78 production rows were blank
# when this was written, so dropping it loses nothing.
class RemoveDispatchIdFromThings < ActiveRecord::Migration[8.1]
  def change
    safety_assured { remove_reference :things, :dispatch, foreign_key: true, index: true, type: :bigint }
  end
end
