# Dispatches kept their origin only as a text snapshot of the terminal's name and address, so editing a location
# broke the link (112 recent dispatches). Store the location itself, filled in from the text.
class AddOriginLocationToDispatches < ActiveRecord::Migration[7.2]
  class MigrationDispatch < ActiveRecord::Base
    self.table_name = 'dispatches'
  end

  def up
    add_reference :dispatches, :origin_location, foreign_key: { to_table: :locations }
    terminals = Location.where(location_category_id: 1).to_a
    MigrationDispatch.where.not(origin: [nil, '']).distinct.pluck(:origin).each do |text|
      location = DispatchOrigin.resolve(text, terminals)
      MigrationDispatch.where(origin: text).update_all(origin_location_id: location.id) if location # rubocop:disable Rails/SkipsModelValidations
    end
  end

  def down
    remove_reference :dispatches, :origin_location, foreign_key: { to_table: :locations }
  end
end
