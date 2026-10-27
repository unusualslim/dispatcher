# rubocop:disable Metrics/ClassLength, Metrics/MethodLength, Layout/LineLength -- the kit data reads best whole
# Non-inventory cost lines from the kit tabs of the internal "MASTER PRICING MATRIX - NEW MASTER 10.17.26" workbook.
# Each tab block is a package template (1/2.5 gal squat, 55 gal drum...); its pallet, film, tape, labels, handling,
# overhead and labor lines become cost lines (priced from the cost item catalog) on the finished goods packed that
# way. Lines are sized so each template's per-unit cost matches the sheet: per = item price / sheet cost, or
# gallons for per-gallon items; labor is hours at the labor rate (per = units per hour = rate / sheet labor cost).
# Products that already have cost lines are left alone, except REPLACE (hand-entered test lines).
class LoadKitCostLines < ActiveRecord::Migration[7.2]
  # template => [[cost item, description (nil = item name), quantity, per], ...]
  TEMPLATES = {
    'DEF 2.5G to 330G|1/2.5 GAL (SQUAT)' => [
      ['WATER & CONVERSION COST', nil, 2.5, 1],
      ['SHRINK WRAP 80ga (20"x5000\')', nil, 1, 4480],
      ['PALLET 48x40', nil, 1, 80],
      ['2 INCH BOX MACHINE TAPE', nil, 1, 1199.4667],
      ['CORNERBOARD 40"', nil, 1, 20],
      ['DO NOT DOUBLE STACK LABEL (500/roll)', nil, 1, 20_000],
      ['SHIPPING LABELS / COA PAPERWORK', nil, 1, 1],
      ['FIXED LABOR & OVERHEAD', nil, 2.5, 1],
      ['VARIABLE LABOR SUPERVISOR', 'Supervisor labor', 1, 273.5291],
      ['VARIABLE LABOR 4 EMPLOYEES W/SUPERVISION', 'Crew labor', 1, 134.3338]
    ],
    'DEF 2.5G to 330G|1/2.5 GAL (TALL) - 1 LABEL' => [
      ['WATER & CONVERSION COST', nil, 2.5, 1],
      ['SHRINK WRAP 80ga (20"x5000\')', nil, 1, 4480],
      ['PALLET 48x40', nil, 1, 80],
      ['3 INCH BOX MACHINE TAPE', nil, 1, 750],
      ['BOX GLUE', nil, 1, 5280],
      ['CORNERBOARD 40"', nil, 1, 20],
      ['DO NOT DOUBLE STACK LABEL (500/roll)', nil, 1, 24_000],
      ['SHIPPING LABELS / COA PAPERWORK', nil, 1, 1],
      ['FIXED LABOR & OVERHEAD', nil, 2.5, 1],
      ['VARIABLE LABOR SUPERVISOR', 'Supervisor labor', 1, 385.0058],
      ['VARIABLE LABOR 4 EMPLOYEES W/SUPERVISION', 'Crew labor', 1, 134.3338]
    ],
    'DEF 2.5G to 330G|1/2.5 GAL (TALL) - 2 LABELS' => [
      ['WATER & CONVERSION COST', nil, 2.5, 1],
      ['SHRINK WRAP 80ga (20"x5000\')', nil, 1, 4480],
      ['PALLET 48x40', nil, 1, 80],
      ['3 INCH BOX MACHINE TAPE', nil, 1, 750],
      ['BOX GLUE', nil, 1, 5280],
      ['CORNERBOARD 40"', nil, 1, 20],
      ['DO NOT DOUBLE STACK LABEL (500/roll)', nil, 1, 24_000],
      ['SHIPPING LABELS / COA PAPERWORK', nil, 1, 1],
      ['FIXED LABOR & OVERHEAD', nil, 2.5, 1],
      ['VARIABLE LABOR SUPERVISOR', 'Supervisor labor', 1, 385.0058],
      ['VARIABLE LABOR 4 EMPLOYEES W/SUPERVISION', 'Crew labor', 1, 134.3338]
    ],
    'DEF 2.5G to 330G|2/2.5 GAL (TALL) - 1 LABEL' => [
      ['WATER & CONVERSION COST', nil, 5, 1],
      ['SHRINK WRAP 80ga (20"x5000\')', nil, 1, 2240],
      ['PALLET 48x40', nil, 1, 40],
      ['2 INCH BOX MACHINE TAPE', nil, 1, 719.68],
      ['CORNERBOARD 40"', nil, 1, 10],
      ['DO NOT DOUBLE STACK LABEL (500/roll)', nil, 1, 10_000],
      ['SHIPPING LABELS / COA PAPERWORK', nil, 1, 1],
      ['FIXED LABOR & OVERHEAD', nil, 2.5, 1],
      ['VARIABLE LABOR SUPERVISOR', 'Supervisor labor', 1, 1008.0151],
      ['VARIABLE LABOR 4 EMPLOYEES W/SUPERVISION', 'Crew labor', 1, 200.4566]
    ],
    'DEF 2.5G to 330G|2/2.5 GAL (TALL) - 2 LABELS' => [
      ['WATER & CONVERSION COST', nil, 5, 1],
      ['SHRINK WRAP 80ga (20"x5000\')', nil, 1, 2240],
      ['PALLET 48x40', nil, 1, 40],
      ['2 INCH BOX MACHINE TAPE', nil, 1, 719.68],
      ['CORNERBOARD 40"', nil, 1, 10],
      ['DO NOT DOUBLE STACK LABEL (500/roll)', nil, 1, 10_000],
      ['SHIPPING LABELS / COA PAPERWORK', nil, 1, 1],
      ['FIXED LABOR & OVERHEAD', nil, 2.5, 1],
      ['VARIABLE LABOR SUPERVISOR', 'Supervisor labor', 1, 1008.0151],
      ['VARIABLE LABOR 4 EMPLOYEES W/SUPERVISION', 'Crew labor', 1, 200.4566]
    ],
    'DEF 2.5G to 330G|DEF 5G PAIL' => [
      ['WATER & CONVERSION COST', nil, 5, 1],
      ['FIXED LABOR & OVERHEAD', nil, 5, 1],
      ['VARIABLE LABOR SUPERVISOR', 'Supervisor labor', 1, 148.7522],
      ['SHRINK WRAP 80ga (20"x5000\')', nil, 1, 5000],
      ['PALLET 48x45 GRADE A', nil, 1, 42]
    ],
    'DEF 2.5G to 330G|55 GAL DRUM - CLOSED TOP' => [
      ['DRUM/TOTE LABEL', nil, 1, 1],
      ['WATER & CONVERSION COST', nil, 55, 1],
      ['SHRINK WRAP 80ga (20"x5000\')', nil, 1, 224],
      ['PALLET 48x48', nil, 1, 4],
      ['DRUM SHIPPING LABEL', nil, 1, 4],
      ['VARIABLE LABOR SUPERVISOR', 'Supervisor labor', 1, 6.3001]
    ],
    'DEF 2.5G to 330G|275 GAL TOTE - OPEN TOP' => [
      ['WATER & CONVERSION COST', nil, 275, 1],
      ['DRUM/TOTE LABEL', nil, 1, 1],
      ['FIXED LABOR & OVERHEAD', nil, 275, 1]
    ],
    'DEF 2.5G to 330G|330 GAL TOTE - OPEN TOP' => [
      ['WATER & CONVERSION COST', nil, 330, 1],
      ['DRUM/TOTE LABEL', nil, 1, 1],
      ['FIXED LABOR & OVERHEAD', nil, 275, 1]
    ],
    'DEF 2.5G to 330G|330 GAL TOTE - CLOSED TOP' => [
      ['WATER & CONVERSION COST', nil, 330, 1],
      ['DRUM/TOTE LABEL', nil, 1, 1],
      ['FIXED LABOR & OVERHEAD', nil, 275, 1]
    ],
    'OIL 2.6OZ to 64OZ|OIL - 24/2.6 OZ' => [
      ['FLUID/OIL HANDLING COST', nil, 0.4875, 1],
      ['BOX INKJET PRINTER INK', nil, 1, 1],
      ['SHRINK WRAP 80ga (20"x5000\')', nil, 1, 11_200],
      ['PALLET 48x40', nil, 1, 200],
      ['2 INCH BOX MACHINE TAPE', nil, 1, 1439.36],
      ['SHIPPING LABELS / COA PAPERWORK', nil, 1, 1],
      ['VARIABLE LABOR 5 EMPLOYEES W/SUPERVISION', 'Crew labor', 1, 63],
      ['OVERHEAD - PACKAGED', nil, 0.4875, 1]
    ],
    'OIL 2.6OZ to 64OZ|OIL - 24/6.4 OZ' => [
      ['FLUID/OIL HANDLING COST', nil, 1.2, 1],
      ['BOX INKJET PRINTER INK', nil, 1, 1],
      ['SHRINK WRAP 80ga (20"x5000\')', nil, 1, 6720],
      ['PALLET 48x40', nil, 1, 120],
      ['2 INCH BOX MACHINE TAPE', nil, 1, 1028.1143],
      ['SHIPPING LABELS / COA PAPERWORK', nil, 1, 1],
      ['VARIABLE LABOR 5 EMPLOYEES W/SUPERVISION', 'Crew labor', 1, 63],
      ['OVERHEAD - PACKAGED', nil, 1.2, 1]
    ],
    'OIL 2.6OZ to 64OZ|OIL - 6/1 QT' => [
      ['FLUID/OIL HANDLING COST', nil, 1.5, 1],
      ['BOX INKJET PRINTER INK', nil, 1, 1],
      ['SHRINK WRAP 80ga (20"x5000\')', nil, 1, 7000],
      ['PALLET 48x40', nil, 1, 125],
      ['2 INCH BOX MACHINE TAPE', nil, 1, 1499.3333],
      ['SHIPPING LABELS / COA PAPERWORK', nil, 1, 1],
      ['VARIABLE LABOR 5 EMPLOYEES W/SUPERVISION', 'Crew labor', 1, 150],
      ['FIXED LABOR & OVERHEAD', nil, 1.5, 1]
    ],
    'OIL 2.6OZ to 64OZ|OIL - 9/64 OZ' => [
      ['BOX INKJET PRINTER INK', nil, 1, 1],
      ['SHRINK WRAP 80ga (20"x5000\')', nil, 1, 2800],
      ['PALLET 48x40', nil, 1, 50],
      ['2 INCH BOX MACHINE TAPE', nil, 1, 749.6667],
      ['SHIPPING LABELS / COA PAPERWORK', nil, 1, 1],
      ['VARIABLE LABOR 5 EMPLOYEES W/SUPERVISION', 'Crew labor', 1, 100],
      ['OVERHEAD - PACKAGED', nil, 4.5, 1]
    ],
    'OIL 1GAL - 55G|2.5G TURKEY JUG' => [
      ['BOX LABELS FOR TURKEY BOXES', nil, 1, 0.5],
      ['FLUID/OIL HANDLING COST', nil, 2.5, 1],
      ['BOX INKJET PRINTER INK', nil, 1, 1],
      ['SHRINK WRAP 80ga (20"x5000\')', nil, 1, 4480],
      ['PALLET 48x40', nil, 1, 80],
      ['SHIPPING LABELS / COA PAPERWORK', nil, 1, 1],
      ['VARIABLE LABOR 5 EMPLOYEES W/SUPERVISION', 'Crew labor', 1, 55],
      ['OVERHEAD - PACKAGED', nil, 2.5, 1]
    ],
    'OIL 1GAL - 55G|3G TURKEY JUG' => [
      ['BOX LABELS FOR TURKEY BOXES', nil, 1, 0.5],
      ['FLUID/OIL HANDLING COST', nil, 3, 1],
      ['BOX INKJET PRINTER INK', nil, 1, 1],
      ['SHRINK WRAP 80ga (20"x5000\')', nil, 1, 4480],
      ['PALLET 48x40', nil, 1, 80],
      ['SHIPPING LABELS / COA PAPERWORK', nil, 1, 1],
      ['VARIABLE LABOR 5 EMPLOYEES W/SUPERVISION', 'Crew labor', 1, 65],
      ['OVERHEAD - PACKAGED', nil, 3, 1]
    ],
    'OIL 1GAL - 55G|4/1 GAL' => [
      ['BOX INKJET PRINTER INK', nil, 1, 4],
      ['SHRINK WRAP 80ga (20"x5000\')', nil, 1, 2800],
      ['PALLET 48x40', nil, 1, 50],
      ['2 INCH BOX MACHINE TAPE', nil, 1, 1199.4667],
      ['SHIPPING LABELS / COA PAPERWORK', nil, 1, 1],
      ['VARIABLE LABOR 5 EMPLOYEES W/SUPERVISION', 'Crew labor', 1, 57.5]
    ],
    'OIL 1GAL - 55G|6/1 GAL' => [
      ['BOX INKJET PRINTER INK', nil, 1, 1],
      ['SHRINK WRAP 80ga (20"x5000\')', nil, 1, 2016],
      ['PALLET 48x40', nil, 1, 36],
      ['2 INCH BOX MACHINE TAPE', nil, 1, 999.5556],
      ['SHIPPING LABELS / COA PAPERWORK', nil, 1, 1],
      ['VARIABLE LABOR 5 EMPLOYEES W/SUPERVISION', 'Crew labor', 1, 55],
      ['OVERHEAD - PACKAGED', nil, 6, 1]
    ],
    'OIL 1GAL - 55G|6/96 OZ' => [
      ['BOX INKJET PRINTER INK', nil, 1, 1],
      ['SHRINK WRAP 80ga (20"x5000\')', nil, 1, 2016],
      ['PALLET 48x40', nil, 1, 36],
      ['2 INCH BOX MACHINE TAPE', nil, 1, 999.5556],
      ['SHIPPING LABELS / COA PAPERWORK', nil, 1, 1],
      ['VARIABLE LABOR 5 EMPLOYEES W/SUPERVISION', 'Crew labor', 1, 87.5]
    ],
    'OIL 1GAL - 55G|5G HTL PAIL' => [
      ['PERRY BROTHERS HANDLING COST', nil, 5, 1],
      ['SHRINK WRAP 80ga (20"x5000\')', nil, 1, 5000],
      ['PALLET 48x48', nil, 1, 36.3803],
      ['VARIABLE LABOR 4 EMPLOYEES W/SUPERVISION', 'Crew labor', 1, 62.5],
      ['OVERHEAD - PACKAGED', nil, 5, 1]
    ],
    'OIL 1GAL - 55G|55G DRUM' => [
      ['PERRY BROTHERS HANDLING COST', nil, 55, 1],
      ['SHRINK WRAP 80ga (20"x5000\')', nil, 1, 5000],
      ['PALLET 48x40', nil, 1, 5.36],
      ['DRUM/TOTE LABEL', nil, 1, 1],
      ['VARIABLE LABOR 4 EMPLOYEES W/SUPERVISION', 'Crew labor', 1, 8.9788],
      ['OVERHEAD - PACKAGED', nil, 55, 1]
    ],
    'OIL 1GAL - 55G|4/4 LITER' => [
      ['FLUID/OIL HANDLING COST', nil, 4, 1],
      ['BOX INKJET PRINTER INK', nil, 1, 1],
      ['SHRINK WRAP 80ga (20"x5000\')', nil, 1, 2800],
      ['PALLET 48x40', nil, 1, 50],
      ['2 INCH BOX MACHINE TAPE', nil, 1, 1199.4667],
      ['SHIPPING LABELS / COA PAPERWORK', nil, 1, 1],
      ['VARIABLE LABOR 5 EMPLOYEES W/SUPERVISION', 'Crew labor', 1, 55],
      ['FIXED LABOR & OVERHEAD', nil, 4, 1]
    ],
    'HTF|5G PAILS' => [
      ['PAIL LABEL - (8.375" x 10.875")', nil, 1, 1],
      ['VARIABLE LABOR SUPERVISOR', 'Supervisor labor', 1, 437.5066],
      ['PAIL LABOR REPACK FEE', nil, 1, 1],
      ['SHRINK WRAP 80ga (20"x5000\')', nil, 1, 5000],
      ['PALLET 48x48', nil, 1, 42],
      ['FLUID/OIL HANDLING COST', nil, 5, 1]
    ],
    'HTF|55 GALLON DRUMS' => [
      ['DRUM/TOTE LABEL', nil, 1, 1],
      ['VARIABLE LABOR 4 EMPLOYEES W/SUPERVISION', 'Crew labor', 1, 18.6667],
      ['DRUM LABOR REPACK FEE', nil, 1, 1],
      ['SHRINK WRAP 80ga (20"x5000\')', nil, 1, 5000],
      ['PALLET 48x48', nil, 1, 3.6716],
      ['SHIPPING LABELS / COA PAPERWORK', nil, 1, 1],
      ['FLUID/OIL HANDLING COST', nil, 55, 1]
    ],
    'HTF|275GAL TOTE' => [
      ['DRUM/TOTE LABEL', nil, 1, 1],
      ['VARIABLE LABOR 4 EMPLOYEES W/SUPERVISION', 'Crew labor', 1, 2.8409],
      ['275 GAL TOTE LABOR REPACK FEE', nil, 1, 1],
      ['SHIPPING LABELS / COA PAPERWORK', nil, 1, 1],
      ['FLUID/OIL HANDLING COST', nil, 275, 1]
    ],
    'HTF|330 GAL TOTE' => [
      ['DRUM/TOTE LABEL', nil, 1, 1],
      ['VARIABLE LABOR 4 EMPLOYEES W/SUPERVISION', 'Crew labor', 1, 2.8409],
      ['330 GAL TOTE LABOR REPACK FEE', nil, 1, 1],
      ['SHIPPING LABELS / COA PAPERWORK', nil, 1, 1],
      ['FLUID/OIL HANDLING COST', nil, 275, 1]
    ],
    'WW & RV AF|6/1 GAL' => [
      ['BOX INKJET PRINTER INK', nil, 1, 4],
      ['SHRINK WRAP 80ga (20"x5000\')', nil, 1, 2016],
      ['PALLET 48x40', nil, 1, 36],
      ['2 INCH BOX MACHINE TAPE', nil, 1, 999.5556],
      ['VARIABLE LABOR 4 EMPLOYEES W/SUPERVISION', 'Crew labor', 1, 181.1594],
      ['OVERHEAD - PACKAGED', nil, 6, 1]
    ],
    'WW & RV AF|55 GAL DRUM' => [
      ['DRUM/TOTE LABEL', nil, 1, 1],
      ['SHRINK WRAP 80ga (20"x5000\')', nil, 1, 224],
      ['PALLET 48x48', nil, 1, 4],
      ['VARIABLE LABOR 4 EMPLOYEES W/SUPERVISION', 'Crew labor', 1, 3.6542]
    ],
    'WW & RV AF|330 GAL TOTE' => [
      ['PERRY BROTHERS HANDLING COST', nil, 330, 1],
      ['DRUM/TOTE LABEL', nil, 1, 1],
      ['FIXED LABOR & OVERHEAD', nil, 275, 1]
    ],
    'AFC|55 GAL DRUM' => [
      ['DRUM/TOTE LABEL', nil, 1, 1],
      ['PERRY BROTHERS HANDLING COST', nil, 55, 1],
      ['SHRINK WRAP 80ga (20"x5000\')', nil, 1, 224],
      ['PALLET 48x48', nil, 1, 4],
      ['VARIABLE LABOR 4 EMPLOYEES W/SUPERVISION', 'Crew labor', 1, 3.6542]
    ],
    'AFC|330 GAL TOTE' => [
      ['PERRY BROTHERS HANDLING COST', nil, 330, 1],
      ['DRUM/TOTE LABEL', nil, 1, 1],
      ['VARIABLE LABOR 4 EMPLOYEES W/SUPERVISION', 'Crew labor', 1, 1.2181]
    ]
  }.freeze

  REPLACE = %w[022BBCJ00DEF086].freeze

  PRODUCTS = {
    'DEF 2.5G to 330G|1/2.5 GAL (SQUAT)' => %w[022BBCJ00DEF086 074002709800 541079 AR57 457PR BADEF2.5 FPS002 MDEF25 023BBCJ00DEF086 2363453],
    'DEF 2.5G to 330G|1/2.5 GAL (TALL) - 1 LABEL' => %w[1092718],
    'DEF 2.5G to 330G|1/2.5 GAL (TALL) - 2 LABELS' => ['BLUE LEAF 96207'],
    'DEF 2.5G to 330G|2/2.5 GAL (TALL) - 1 LABEL' => %w[520562P 1516 810133546197 MIGHTYDEF DEF051 FPS005 225 ROADCHAMP 80301],
    'DEF 2.5G to 330G|2/2.5 GAL (TALL) - 2 LABELS' => %w[022BBCJ00DEF088 023BBCJ00DEF088 TRUDEF005],
    'DEF 2.5G to 330G|DEF 5G PAIL' => %w[022BBCJ00DEF150 1289619],
    'DEF 2.5G to 330G|55 GAL DRUM - CLOSED TOP' => ['1580-D', '1000155', 'BLUE LEAF 96208', 'CC2904', '022BBCJ00DEF163', '2362477', '154969'],
    'DEF 2.5G to 330G|275 GAL TOTE - OPEN TOP' => %w[520561P CC2905-FP 023BBCJ00DEF175 022BBCJ00DEF175 2362476],
    'DEF 2.5G to 330G|330 GAL TOTE - OPEN TOP' => ['BLUE LEAF 96209', '022BBCJ00DEF179', '550060'],
    'DEF 2.5G to 330G|330 GAL TOTE - CLOSED TOP' => %w[1580],
    'OIL 2.6OZ to 64OZ|OIL - 24/2.6 OZ' => %w[041FPBSBLEND016 590-2426],
    'OIL 2.6OZ to 64OZ|OIL - 24/6.4 OZ' => %w[041FPBSBLEND025 590-2464],
    'OIL 2.6OZ to 64OZ|OIL - 6/1 QT' => %w[010ENAHBLCVT052 010ENAH00CVT052 010ENAHRDCVT052],
    'OIL 2.6OZ to 64OZ|OIL - 9/64 OZ' => %w[1464 8564 9064 64MT 64AT],
    'OIL 1GAL - 55G|2.5G TURKEY JUG' => %w[S2G],
    'OIL 1GAL - 55G|3G TURKEY JUG' => %w[S3G],
    'OIL 1GAL - 55G|4/1 GAL' => %w[520560P 520589P 520590P 520593P 520594P 520595P 015AFFXALLSN077 015AFBTXTRME077],
    'OIL 1GAL - 55G|6/1 GAL' => %w[CS1G S1G],
    'OIL 1GAL - 55G|6/96 OZ' => %w[1496 8596 9096 96MT 96AT],
    'OIL 1GAL - 55G|5G HTL PAIL' => %w[TRANSYND 222290448 B1000 B12],
    'OIL 1GAL - 55G|55G DRUM' => %w[10006000 10006004 701010300 226606 223508990 221880 67254 5040 5050 5060 6525917901 7910901 7574901 6525566901 6524565901 5030 METHANOL FPS007 10066304 006CDDV75W85155 222290981 K1000 10003972 ATFA55],
    'OIL 1GAL - 55G|4/4 LITER' => %w[HH0496 HH0494 M02644],
    'HTF|5G PAILS' => %w[041FDBT72CNC150 041FDBT99CNC150 20570200 20500200 20500000 10530200 10540200 10550200 10530100 10535100 10540100 10550100 10560100 10500100 10530203 10540203 10550203],
    'HTF|55 GALLON DRUMS' => %w[030DQGH0CONC167 45550500 45500500 25540200 25550200 25570200 25500200 25530000 25535000 25550000 25570000 25500000 15530200 15540200 15550200 15530100 15535100 15540100 15550100 15560100 15500100 15540300 15550300 35550200 15530203 15540203 15550203 25570002 25500002],
    'HTF|275GAL TOTE' => %w[030CMGI0CONC174 27530200 27550200 27500200 17530100 17540100 17500100 17535300 17540300],
    'HTF|330 GAL TOTE' => %w[23300200 23300000 13335300 13340300 03300000],
    'WW & RV AF|6/1 GAL' => %w[520601P 520602P NC313 10678 10679 10677 041FIBTWSHER083 041FJBTWSHER083 041FFBTWSHER083 041FLBTWSHER083 041FHBTWSHER083 028AEFTRVAFC083 ATWWZX ATWWAX 622020-35 2291508 823026 823023],
    'WW & RV AF|55 GAL DRUM' => %w[10090055 NC315 041FIBTWSHER166 041FJBTWSHER166 041FFBTWSHER166 041FLBTWSHER166 041FDBT72CNC166 041FDBT99CNC166 041FHBTWSHER166 028AEFTRVAFC167 METH55-CLEAR],
    'WW & RV AF|330 GAL TOTE' => %w[028AEFTRVAFC179],
    'AFC|55 GAL DRUM' => %w[10070873B 1859941B CC2826 CC2821 CC36074B CC2745 CC2739 028AEAX50/50167 028AEAX0CONC167 028AEBA50/50167 028AEBA0CONC167 028AEBB50/50167 028AEBB60/40167 028AEBB0CONC167 028AEAZ50/50167 028AEAZ0CONC167],
    'AFC|330 GAL TOTE' => %w[028AEAX50/50178 028AEAX0CONC178 028AEBA50/50178 028AEBA0CONC178 028AEBB50/50178 028AEBB60/40178 028AEBB0CONC178 028AEAZ50/50178 028AEAZ0CONC178]
  }.freeze

  def up
    execute <<~SQL.squish
      INSERT INTO cost_items (name, reporting_group_id, unit_cost, unit, vendor, notes, active, created_at, updated_at)
      SELECT 'OVERHEAD - PACKAGED', id, 0.03, 'gallon', 'FPS', 'Overhead .03 per gallon on the packaged kit tabs.', TRUE,
             NOW(), NOW()
      FROM reporting_groups WHERE name = 'Overhead'
      ON CONFLICT (name) DO NOTHING
    SQL
    PRODUCTS.each { |template, ids| ids.each { |id| add_lines(id, TEMPLATES.fetch(template)) } }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def add_lines(product_id, lines)
    return unless select_value("SELECT 1 FROM products WHERE id = #{q(product_id)}")

    execute "DELETE FROM product_cost_lines WHERE product_id = #{q(product_id)}" if REPLACE.include?(product_id)
    return if select_value("SELECT 1 FROM product_cost_lines WHERE product_id = #{q(product_id)}")

    lines.each_with_index do |(item, description, quantity, per), position|
      execute <<~SQL.squish
        INSERT INTO product_cost_lines (product_id, cost_item_id, reporting_group_id, description, quantity, unit_cost,
                                        per_quantity, position, created_at, updated_at)
        SELECT #{q(product_id)}, id, reporting_group_id, #{q(description || item)}, #{quantity}, unit_cost, #{per},
               #{position}, NOW(), NOW()
        FROM cost_items WHERE name = #{q(item)}
      SQL
    end
  end

  def q(value)
    connection.quote(value)
  end
end
# rubocop:enable Metrics/ClassLength, Metrics/MethodLength, Layout/LineLength
