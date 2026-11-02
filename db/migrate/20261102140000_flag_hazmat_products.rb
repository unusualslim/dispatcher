# rubocop:disable Rails/SkipsModelValidations -- data migration on a bare model
# Turns on the hazmat flag (with the DOT shipping description printed on the BOL) for products that are hazardous at
# any size, from a review of names and BOM methanol content on 2026-11-02. Methanol washer fluids from -20 down are
# flammable (about 35-46% methanol); Zero Degree (22%) is combustible, regulated only in bulk, so only its bulk item
# is flagged. 6/1 gal cases ship as Limited Quantity and stay unflagged. Descriptions can be corrected on each product.
class FlagHazmatProducts < ActiveRecord::Migration[7.2]
  class Product < ActiveRecord::Base
    self.table_name = 'products'
  end

  METHANOL = 'UN1230, Methanol, 3 (6.1), PG II'.freeze
  METHANOL_SOLUTION = 'UN1993, Flammable liquid, n.o.s. (methanol), 3, PG II'.freeze
  WASHER = 'UN1993, Flammable liquid, n.o.s. (methanol), 3, PG III'.freeze
  COMBUSTIBLE_WASHER = 'NA1993, Combustible liquid, n.o.s. (methanol), CBL, PG III'.freeze

  DESCRIPTIONS = {
    '091580190' => 'UN1814, Potassium hydroxide solution, 8, PG II',
    '041FDBT99CNC187' => METHANOL, '041FDBT99CNC166' => METHANOL, '041FDBT99CNC150' => METHANOL,
    '041FDBT72CNC187' => METHANOL_SOLUTION, '041FDBT72CNC166' => METHANOL_SOLUTION,
    '041FDBT72CNC150' => METHANOL_SOLUTION, 'METHANOL64' => METHANOL_SOLUTION,
    '041FIBTWSHER187' => WASHER, '041FIBTWSHER166' => WASHER, 'NC315' => WASHER,
    '041FJBTWSHER187' => WASHER, '041FJBTWSHER166' => WASHER,
    '041FLBTWSHER187' => WASHER, '041FLBTWSHER166' => WASHER, '10038227B' => WASHER,
    'METH55-CLEAR' => WASHER,
    '041FHBTWSHER187' => COMBUSTIBLE_WASHER
  }.freeze

  # METH55-CLEAR was already flagged, with PDI's straight-methanol description.
  METH55_OLD = 'UN1230, Hazard Class 3, Packing Group II'.freeze

  def up
    DESCRIPTIONS.each do |id, description|
      Product.where(id: id).update_all(hazmat: true, hazmat_description: description, updated_at: Time.current)
    end
  end

  def down
    Product.where(id: DESCRIPTIONS.keys - ['METH55-CLEAR'])
           .update_all(hazmat: false, hazmat_description: nil, updated_at: Time.current)
    Product.where(id: 'METH55-CLEAR').update_all(hazmat_description: METH55_OLD, updated_at: Time.current)
  end
end
# rubocop:enable Rails/SkipsModelValidations
