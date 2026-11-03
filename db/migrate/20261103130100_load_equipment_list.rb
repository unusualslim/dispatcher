# rubocop:disable Layout/LineLength -- the asset list reads best whole
# One-time load of the equipment list from "Five Points Assets (Project Data).csv" (2026-11-03) into Equipment &
# Assets (things, category equipment). The sheet's location names map to PDI sites (production has two
# "Five Points South" records; 0110 is the PDI one); unmatched ones are left blank and listed in the output. Repeated names are numbered (#1, #2...) so pickers can tell them apart.
# "none" / "TBD" / blank cells are left empty. Skips any asset already loaded (same name).
class LoadEquipmentList < ActiveRecord::Migration[7.2]
  SITES = { 'Five Points South' => '0110', 'Five Points Main' => '0002', 'Perry Brothers Oil' => '2171' }.freeze

  FIELDS = %i[name serial_number location production_line install_status power purchased_from invoice_number
              year_made].freeze

  # [name, serial #, location, line / project, status, power, purchased from, invoice #, year made]
  ASSETS = [
    ['Big ass Fan 28" #1', nil, 'Five Points South', 'South-Building Improvements', 'Complete', '480V', 'Heritage Global Partners', nil, nil],
    ['Big ass Fan 28" #2', nil, 'Five Points South', 'South-Building Improvements', 'Complete', '480V', 'Heritage Global Partners', nil, nil],
    ['Big ass Fan 28" #3', nil, 'Five Points South', 'South-Building Improvements', 'Complete', '480V', 'Heritage Global Partners', nil, nil],
    ['Big ass Fan 28" #4', nil, nil, nil, 'In Progress', '480V', 'Heritage Global Partners', nil, nil],
    ['Big Ass Fan 12"', nil, nil, nil, 'In Progress', '480V', nil, nil, nil],
    ['Inline Blender', nil, nil, nil, nil, nil, 'Dilmar', nil, nil],
    ['E-Pak 4 Station Spindle Capper', nil, 'Five Points Main', 'Main-DEF Tall Single Line', 'In Progress', '110V', 'E-Pak', '76677', nil],
    ['E-Pak Cap Sorting Elevator', nil, nil, nil, nil, '110V', 'E-Pak', '76677', nil],
    ['4 Head Automatic Pressure Filler', nil, 'Perry Brothers Oil', 'South-Turkey Box Line', 'Complete', '240V', 'E-Pak', '76677', nil],
    ['Wexxar WF20T Case Erector', '3187', 'Five Points South', 'South-Oil-Gallon Line', 'Complete', '110v', nil, nil, nil],
    ['Wexxar WF20 Case Erector', nil, nil, nil, nil, nil, nil, nil, nil],
    ['Pack Leader Pro-625 Labeler', '00115pro6250010302', 'Five Points South', 'South-Oil Quart Line', 'In Progress', '110V', nil, nil, nil],
    ['Eagle TC20CF Case Erector', nil, 'Five Points South', nil, nil, '110V', 'Atlantic Tape & Packaging', nil, nil],
    ['Eagle T500 Top/botton Taper', 'FC194975', 'Five Points South', 'South-Oil-Gallon Line', 'Complete', '110V', 'Atlantic Tape & Packaging', nil, nil],
    ['China 8 head Auotomatic Filler', nil, 'Five Points South', 'South-Oil Quart Line', 'In Progress', '220V', nil, nil, nil],
    ['China Labeler /w hold down', nil, 'Five Points South', 'South-Oil-Gallon Line', 'Complete', '110V', 'W.R. Turner?', nil, nil],
    ['Foil Sealer AM-250', 'A27461', 'Five Points South', 'South-Oil-Gallon Line', 'Complete', '220V', nil, nil, nil],
    ['Kaps-All A-2 6 Spindle Capper', '3840', 'Five Points South', nil, 'In Progress', '220V 3 phase', nil, nil, nil],
    ['Custom 6 head diving 1gal filler', nil, 'Five Points South', 'South Antifreeze F-style 1 Gal', 'In Progress', '110V', nil, nil, nil],
    ['Custom 8 head diving pressure overflow filler', nil, 'Five Points South', 'South-RV Antifreeze Line', 'Complete', '208V 3 phase', 'W.R. Turner?', nil, nil],
    ['Kaps-All A6-R', '7692', 'Five Points South', 'South-RV Antifreeze Line', 'Complete', '220V 3 phase', nil, nil, nil],
    ['Universal Labeller', nil, 'Five Points South', 'South-RV Antifreeze Line', nil, '110V', nil, nil, nil],
    ['Combi Top Taper TBF', 'TBF593118', 'Five Points South', 'South-RV Antifreeze Line', 'Complete', '110V', 'Dilmar', nil, nil],
    ['Combi 2EZSB Case Erector and Picking', '2EZSB499705', 'Five Points South', 'South-RV Antifreeze Line', 'Complete', '240V 3 phase', 'Dilmar', nil, 2016],
    ['Liquid packaging Solutions Capper', nil, 'Five Points South', 'South-Window Wash Line', 'In Progress', '110V', 'W.R. Turner?', nil, nil],
    ['Max Pack Cardboard Baler', nil, nil, nil, nil, '208V 3 phase', 'Auction', nil, nil],
    ['Pearson Case Erector', '2006035011058', 'Five Points South', 'South-Window Wash Line', 'In Progress', '208V 3 phase', nil, nil, nil],
    ['Columbia FL 100 Palletizer', nil, nil, 'South-Window Wash Line', nil, nil, nil, nil, nil],
    ['Hamrick 600D-S Drop packer', '20-2045', 'Five Points South', 'South-Window Wash Line', 'In Progress', '480v 3 phase', nil, nil, nil],
    ['Hamrick Top Taper', '20-2046', 'Five Points South', 'South-Window Wash Line', 'In Progress', nil, nil, nil, nil],
    ['Norwix Case Marking UC22', '800140', 'Five Points South', 'South-Window Wash Line', 'In Progress', '110V', 'Atlantic Tape & Packaging', nil, nil],
    ['Orion RTD Rotary Stretch Wrapper', 'V-3938', 'Five Points South', nil, 'In Progress', '110V', nil, nil, nil],
    ['Ketan LW-250S Labeler', nil, 'Five Points South', nil, 'In Progress', '110V', nil, nil, nil],
    ['Generic Top Taper', nil, 'Five Points South', nil, 'Complete', '110V', nil, nil, nil],
    ['China Heat Seal Machine FQL550', '27053397000102000000', 'Five Points South', 'South-Oil-2 Cycle Line', 'Complete', '220V 1 Phase', 'W.R. Turner', nil, nil],
    ['China Shrink Wrapping Tunnel', '27053397000102051902', 'Five Points South', 'South-Oil-2 Cycle Line', 'Complete', '220V 1 Phase', 'W.R. Turner', nil, nil],
    ['Epak 4 spindle Capper', '1225-76677-216-117', 'Five Points South', nil, 'In Progress', '110V', 'E-Pak', nil, nil],
    ['Epak Capper Elevator', nil, 'Five Points South', nil, 'In Progress', '110V', 'E-Pak', nil, nil],
    ['china small bottle labeler', nil, 'Five Points South', nil, nil, nil, 'Dilmar', nil, nil],
    ['Enercon Super Seal', nil, 'Five Points South', 'South-Oil-2 Cycle Line', 'Complete', nil, nil, nil, nil],
    ['Toyota Forklift - Diesel', 'C1871', 'Five Points South', nil, nil, nil, nil, nil, nil],
    ['Toyota Forklift - LP', nil, 'Five Points Main', nil, nil, nil, nil, nil, nil],
    ['White Forklift #1', nil, 'Five Points Main', nil, nil, nil, nil, nil, nil],
    ['White Forklift #2', nil, 'Five Points Main', nil, nil, nil, nil, nil, nil]
  ].freeze

  def up
    @locations = {}
    ASSETS.each do |row|
      attrs = FIELDS.zip(row).to_h
      next if Thing.exists?(name: attrs[:name])

      Thing.create!(attrs.merge(category: 'equipment', location: location_named(attrs[:location])))
    end
    missing = @locations.select { |name, location| name && location.nil? }.keys
    say "No location named #{missing.join(', ')}; those assets have no location." if missing.any?
  end

  def down
    Thing.where(category: 'equipment', name: ASSETS.map(&:first)).where.missing(:expense_lines).delete_all
  end

  private

  def location_named(name)
    return if name.nil?

    @locations.fetch(name) do
      @locations[name] = Location.where(pdi_site_code: SITES[name]).order(:id).first if SITES[name]
    end
  end
end
# rubocop:enable Layout/LineLength
