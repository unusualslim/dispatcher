# rubocop:disable Metrics/ClassLength -- the price lists read best whole
# One-time load from the internal "MASTER PRICING MATRIX - NEW MASTER 10.17.26" workbook (Master Item-Price sheet):
# - landed prices become the standard cost of the matching products, effective 2026-10-01, replacing any standard
#   cost entered for them on or after that date;
# - the rows without a part number (labels, pallets, film, tape, labor, overhead) become cost items.
class LoadStandardCostMatrix < ActiveRecord::Migration[7.2]
  EFFECTIVE = '2026-10-01'.freeze

  STANDARD_COSTS = {
    '901' => 0.985, '023BBCJ00DEF187' => 1.094,
    'BA2BCTBJ' => 0.667, 'BB2BCTBJ' => 1.146, 'AB2DCTBN' => 0.758, 'AH2BCTBJ' => 1.146, 'AA2ECTBL' => 0.7753,
    'BA2FCTBL' => 0.948, 'AA2ACTAJ' => 0.487, 'AA2ACTAV' => 0.809, 'AA2ECTAY' => 0.432, 'AA2ECTBQ' => 1.701,
    'AA2ECTBF' => 0.702, 'AA2ECTBH' => 1.851, 'AA3ECTBH' => 1.338,
    '219574100000' => 0.1079, '302702104900' => 0.1969, '333405004001' => 0.2547, '902509904000' => 0.6984,
    'IC-BLACKAF-1G' => 0.782, '844501000007' => 0.4187, 'DEFBOTTLE25' => 1.25275, '921709000001' => 1.38,
    'BUCKETBLACK5GA' => 2.786, '90263WHT' => 4.16, '6805 TRVLR' => 4.16, '6812 BLU' => 1.64, 'LID BLACK 5GA' => 1.286,
    'BLKDRUM' => 31.07, 'BLUEDRUM' => 32.08, 'BLUEPOLYDR' => 27.62, 'BLKPOLYDR' => 41.78, 'BEZDF301' => 41.97,
    '27501' => 221.9, '33001' => 237.6,
    '28400BLKHS' => 0.0336, 'DEFCAP' => 0.029, '382F01H' => 0.0312, 'TAMPCAPBLK' => 0.078, '58183' => 0.0568,
    '382381K' => 0.054, '63-S01-2311' => 0.22, '6000010' => 14.72, 'U2' => 0.181, 'SPOUT25' => 0.26,
    '1014113' => 22.37, '1014111' => 22.37, '1014112' => 19.93
  }.freeze

  LABEL_NOTE = 'FOB pricing based on minimum order quantity.'.freeze
  COMBINED_NOTE = 'Based on 50,000 labels (combined).'.freeze

  # [name, group, unit cost, per, vendor, effective date, notes]
  COST_ITEMS = [
    ['1 GAL ROUND LABEL - 5" X 8"', 'Consumables', 0.0778, 'each', 'Better Label', '2026-07-01', COMBINED_NOTE],
    ['1 GAL F-STYLE LABEL - 5" X 5"', 'Consumables', 0.065, 'each', 'Better Label', '2026-08-06', COMBINED_NOTE],
    ['TALL DEF LABEL - 5.5" X 5.5"', 'Consumables', 0.0683, 'each', 'Better Label', '2026-07-01', COMBINED_NOTE],
    ['TALL DEF LABEL - 5.5" X 6"', 'Consumables', 0.1102, 'each', 'Better Label', '2026-05-01', LABEL_NOTE],
    ['BOTTLE LABEL - 1.5" X 1.5"', 'Consumables', 0.0624, 'each', 'Better Label', '2026-05-01', LABEL_NOTE],
    ['BOTTLE LABEL - 2" X 2.5"', 'Consumables', 0.0676, 'each', 'Better Label', '2026-05-01', LABEL_NOTE],
    ['BOTTLE LABEL - 3" X 3" (2 Color)', 'Consumables', 0.1223, 'each', 'Better Label', '2026-05-01', LABEL_NOTE],
    ['BOTTLE LABEL - 3" X 3" (3 Color)', 'Consumables', 0.146, 'each', 'Better Label', '2026-05-01', LABEL_NOTE],
    ['BOTTLE LABEL - 3" X 5"', 'Consumables', 0.0891, 'each', 'Better Label', '2026-05-01', LABEL_NOTE],
    ['BOTTLE LABEL - 3.75" X 3.75"', 'Consumables', 0.05, 'each', 'Better Label', '2026-08-06',
     'Based on existing SPC business.'],
    ['BOTTLE LABEL - 4.75" X 10"', 'Consumables', 0.17285, 'each', 'Better Label', '2026-05-01', LABEL_NOTE],
    ['BOTTLE LABEL FRONT - 6.25" X 5.625"', 'Consumables', 0.0875, 'each', nil, nil, nil],
    ['BOTTLE LABEL BACK - 6.25" X 5.625"', 'Consumables', 0.07625, 'each', nil, nil, nil],
    ['BOX LABELS FOR TURKEY BOXES', 'Consumables', 0.5, 'each', nil, '2026-05-01', nil],
    ['PAIL LABEL - (8.375" x 10.875")', 'Consumables', 0.355, 'each', 'Better Label', '2026-05-01', nil],
    ['DRUM/TOTE LABEL', 'Consumables', 0.4026, 'each', 'Better Label', '2026-05-01', nil],
    ['DRUM SHIPPING LABEL', 'Consumables', 0.1, 'each', nil, '2026-05-01', nil],
    ['DO NOT DOUBLE STACK LABEL (500/roll)', 'Consumables', 33.0, 'roll', 'U-Line', '2026-05-01', nil],
    ['SHIPPING LABELS / COA PAPERWORK', 'Consumables', 0.01, 'each', nil, '2026-05-01', nil],
    ['SHRINK WRAP 80ga (20"x5000\')', 'Consumables', 52.5, 'roll', 'Atlantic Tape', '2026-06-29', nil],
    ['SLIP SHEET 34" X 38"', 'Consumables', 0.454, 'each', 'Atlantic Tape', '2026-04-06', nil],
    ['PALLET 48x40', 'Consumables', 13.4, 'each', 'C&J Pallets', '2026-06-01', nil],
    ['PALLET 48x45 GRADE A', 'Consumables', 14.2, 'each', 'C&J Pallets', '2026-06-01', nil],
    ['PALLET 48x48', 'Consumables', 12.3, 'each', 'C&J Pallets', '2026-06-01', nil],
    ['CORNERBOARD 40"', 'Consumables', 0.497, 'each', 'Atlantic Tape', '2026-04-06', nil],
    ['CORNERBOARD 48"', 'Consumables', 0.585, 'each', 'Atlantic Tape', '2026-04-06', nil],
    ['BOX INKJET PRINTER INK', 'Consumables', 0.04, 'case', nil, nil, 'Estimate (TBD on the matrix).'],
    ['BOX GLUE', 'Consumables', 54.33, 'case', 'Atlantic Tape', '2026-04-06', nil],
    ['3 INCH BOX MACHINE TAPE', 'Consumables', 25.75, 'roll', 'Atlantic Tape', '2026-04-06', '1,000 ft roll.'],
    ['2 INCH BOX MACHINE TAPE', 'Consumables', 21.09, 'roll', 'Atlantic Tape', '2026-04-06', '914 m roll.'],
    ['2 INCH HAND TAPE (100 meters)', 'Consumables', 1.57, 'roll', 'Atlantic Tape', '2026-04-06', nil],
    ['VARIABLE LABOR SUPERVISOR', 'Labor', 285.71, 'day', 'FPS', '2026-04-01', nil],
    ['VARIABLE LABOR 4 EMPLOYEES W/SUPERVISION', 'Labor', 718.36, 'day', 'FPS', '2026-04-01',
     '$22.00/hr fully loaded.'],
    ['VARIABLE LABOR 5 EMPLOYEES W/SUPERVISION', 'Labor', 1000.0, 'day', 'FPS', '2026-04-02',
     '$22.00/hr fully loaded.'],
    ['WATER & CONVERSION COST', 'Overhead', 0.02, 'gallon', 'FPS', '2026-07-22', nil],
    ['FED SUPERFUND TAX', 'Overhead', 0.00437, 'gallon', 'FPS', '2025-10-15',
     'Included in the fluid price on the kits.'],
    ['FIXED LABOR & OVERHEAD', 'Overhead', 0.07572, 'gallon', 'FPS', '2026-07-22', nil],
    ['FLUID/OIL HANDLING COST', 'Overhead', 0.1, 'gallon', 'FPS', '2026-05-01', nil],
    ['PERRY BROTHERS HANDLING COST', 'Overhead', 0.02, 'gallon', 'FPS', '2026-09-21', nil],
    ['BULK BLENDING REPACK FEE', 'Overhead', 0.05, 'gallon', 'FPS', '2026-05-01', nil],
    ['NON-DEF CASES REPACK FEE', 'Overhead', 0.6, 'case', 'FPS', '2026-05-01', nil],
    ['DEF CASES REPACK FEE', 'Overhead', 0.75, 'case', 'FPS', '2026-05-01', nil],
    ['PAIL LABOR REPACK FEE', 'Overhead', 1.25, 'each', 'FPS', '2025-09-04', nil],
    ['DRUM LABOR REPACK FEE', 'Overhead', 8.4, 'each', 'FPS', '2025-09-04', nil],
    ['275 GAL TOTE LABOR REPACK FEE', 'Overhead', 16.75, 'each', 'FPS', '2025-09-04', nil],
    ['330 GAL TOTE LABOR REPACK FEE', 'Overhead', 19.75, 'each', 'FPS', '2025-09-04', nil]
  ].freeze

  def up
    load_standard_costs
    load_cost_items
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def load_standard_costs
    STANDARD_COSTS.each do |id, amount|
      next unless select_value("SELECT 1 FROM products WHERE id = #{q(id)}")

      execute <<~SQL.squish
        DELETE FROM standard_cost_histories WHERE product_id = #{q(id)} AND effective_date >= #{q(EFFECTIVE)}
      SQL
      execute <<~SQL.squish
        INSERT INTO standard_cost_histories (product_id, amount, effective_date, notes, created_at, updated_at)
        VALUES (#{q(id)}, #{amount}, #{q(EFFECTIVE)}, 'Master Pricing Matrix 10.17.26 (landed)', NOW(), NOW())
      SQL
      execute "UPDATE products SET standard_cost = #{amount}, updated_at = NOW() WHERE id = #{q(id)}"
    end
  end

  def load_cost_items
    COST_ITEMS.each do |name, group, *values|
      execute <<~SQL.squish
        INSERT INTO cost_items (name, reporting_group_id, unit_cost, unit, vendor, effective_date, notes, active,
                                created_at, updated_at)
        VALUES (#{q(name)}, #{group_id(group)}, #{values.map { |v| q(v) }.join(', ')}, TRUE, NOW(), NOW())
        ON CONFLICT (name) DO NOTHING
      SQL
    end
  end

  def q(value)
    connection.quote(value)
  end

  def group_id(name)
    select_value("SELECT id FROM reporting_groups WHERE name = #{q(name)}") ||
      insert(<<~SQL.squish) # rubocop:disable Rails/SkipsModelValidations -- plain SQL in a data migration
        INSERT INTO reporting_groups (name, item_type, labor, position, costing_method, created_at, updated_at)
        VALUES (#{q(name)}, 'non_inventory', #{name == 'Labor'}, 99, 'weighted_average', NOW(), NOW())
      SQL
  end
end
# rubocop:enable Metrics/ClassLength
