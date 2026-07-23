class VendorsController < ApplicationController
  before_action :require_admin!
  before_action :set_vendor, only: [:show, :edit, :update, :destroy]

  def index
    @vendors = Vendor.all
    @vendor = Vendor.new  # For the form
  end

  def show
  end

  def edit
  end

  def update
    if @vendor.update(vendor_params)
      redirect_to @vendor, notice: "Vendor updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def create
    @vendor = Vendor.new(vendor_params)
    if @vendor.save
      redirect_to vendors_path, notice: "Vendor successfully added."
    else
      @vendors = Vendor.all
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @vendor.destroy
    redirect_to vendors_path, notice: "Vendor successfully deleted."
  end

  def import_preferred_vendors
    vendor_map = {
      'American Mfg'        => '6050',
      'Atlantia Snapseal'   => '6060',
      'Atlantic Tape & Pkg' => '109',
      'BASF'                => '24',
      'Bericap'             => '6110',
      'Better Label'        => '6130',
      'Blue 1 Energy'       => '389',
      'Bomag'               => '2610',
      'Bucket Innovations'  => '6150',
      'CCI'                 => '32',
      'CKS'                 => '337',
      'COMPLEX SALES'       => '39',
      'CUMMINS'             => '51',
      'Cary Company'        => '6680',
      'Centurion'           => '6200',
      'Con-Tech'            => '6280',
      'Crucible Chemical'   => '6830',
      'Dober'               => '6290',
      'Five Points Service' => '1512',
      'Greif'               => '6360',
      'Ideas'               => '6380',
      'International Paper' => '162',
      'Koch Methanol'       => '2813',
      'MKS'                 => '6510',
      'Mauser'              => '1634',
      'Perry Brothers Oil'  => '315',
      'Phoenix Closures'    => '6780',
      'Q8'                  => '6155',
      'Robert Koch Color'   => '6430',
      'TK Supply'           => '6670',
      'TSG'                 => '3831',
      'Weba'                => '6720',
      'Whitaker'            => '6730',
      'Wincom'              => '6740',
    }

    # [product_id, description, uom, cost, primary_vendor_name, secondary_vendor_name]
    rows = [
      ['AA2ECTAY',      'BOX-6/1qt BLANK KRAFT',                  'EA', 1,     'International Paper', 'Atlantic Tape & Pkg'],
      ['AF2FCTBJ-40',   'BOX-2.5 BADASS DEF SQUAT 40ect',         'EA', 1,     'Atlantic Tape & Pkg', nil],
      ['AA3ECTBH',      'BLANK KRAFT ROUND 6/1g BOX',              'EA', 1,     'Atlantic Tape & Pkg', nil],
      ['AA2ECTBH',      'BLANK KRAFT F-STYLE 6/1g BOX',            'EA', 1,     'Atlantic Tape & Pkg', nil],
      ['AA2ECTBF',      'BLANK KRAFT F-STYLE 4/1g BOX',            'EA', 1,     'International Paper', 'Atlantic Tape & Pkg'],
      ['AA2ECTBQ',      'BLANK KRAFT 9/64oz BOX',                  'EA', 0.5,   'Atlantic Tape & Pkg', nil],
      ['AA2ACTAV',      'BLANK KRAFT 24/6.4 (8oz) BOX',            'EA', 0.5,   'Atlantic Tape & Pkg', nil],
      ['AA2ACTAJ',      'BLANK KRAFT 24/2.6 (3oz) BOX',            'EA', 0.5,   'Atlantic Tape & Pkg', nil],
      ['AD2ECTBL',      '2/2.5g ULTRAPURE DEF BOX',                'EA', 1,     'International Paper', 'Atlantic Tape & Pkg'],
      ['AD2ECTBH',      '4/1g BLANK BOX',                          'EA', 1,     'International Paper', 'Atlantic Tape & Pkg'],
      ['AD2ECTBF',      '4/1g BLANK KRAFT BOX',                    'EA', 1,     'International Paper', 'Atlantic Tape & Pkg'],
      ['AD3ECTBH',      '3/1g BLANK BOX',                          'EA', 1,     'International Paper', 'Atlantic Tape & Pkg'],
      ['AD3ECTBF',      '3/1g BLANK KRAFT BOX',                    'EA', 1,     'International Paper', 'Atlantic Tape & Pkg'],
      ['AD3ECTAY',      '3/1QT BOX BLANK',                         'EA', 1,     'International Paper', 'Atlantic Tape & Pkg'],
      ['AA2ECTBL',      'BLANK KRAFT 2/2.5g BOX',                  'EA', 1,     'International Paper', 'Atlantic Tape & Pkg'],
      ['AD4ECTBH',      'BLANK KRAFT 4/1g HANDLE BOX',             'EA', 1,     'International Paper', nil],
      ['AD2ECTBQ',      'BLANK KRAFT 2/64oz BOX',                  'EA', 0.5,   'Atlantic Tape & Pkg', nil],
      ['AA4ECTBH',      'BLANK KRAFT 24/8oz BOX',                  'EA', 0.5,   'Atlantic Tape & Pkg', nil],
      ['DEFCAP',        'WHITE FOIL SEAL 38mm CAP',                'EA', 0.005, 'Phoenix Closures',    'Bomag'],
      ['382F01H',       'BLACK FOIL SEAL 38mm CAP',                'EA', 0.005, 'Phoenix Closures',    'Bomag'],
      ['27401',         'WHITE HDPE 28/410 PUSH CAP',              'EA', 0.005, 'Phoenix Closures',    nil],
      ['28400BLKHS',    '28/400 BLACK HEAT SEAL CAP',              'EA', 0.005, 'Phoenix Closures',    nil],
      ['38MMBLKFS',     'BLACK FOIL SEAL 38mm',                    'EA', 0.005, 'Phoenix Closures',    nil],
      ['SPOUT25',       'CLEAR 38mm SPOUT',                        'EA', 0.005, 'Con-Tech',            'Bomag'],
      ['38400WHTFS',    '38/400 WHITE FOIL SEAL CAP',              'EA', 0.005, 'Phoenix Closures',    nil],
      ['BLUEPOLYDR',    'Recon Blue Poly 55g Drum',                'EA', 25,    'Mauser',              nil],
      ['BEZDF301',      'New Natural Poly Drum',                   'EA', 25,    'Greif',               'Mauser'],
      ['BLKPOLYDR',     'New Black Poly 55g Drum',                 'EA', 25,    'Greif',               'Mauser'],
      ['BLKDRUM',       'DRUM - RECON SOLID BLACK STEEL UNLINED',  'EA', 50,    'Mauser',              nil],
      ['BLUEDRUM',      'DRUM - CHV BLU STEEL RECON LINED',        'EA', 50,    'Mauser',              nil],
      ['33001',         '330 GAL IBC TOTE w/ CAGE',                'EA', 160,   'Centurion',           'Mauser'],
      ['27501',         'New Def 275g Tote',                       'EA', 130,   'Centurion',           'Mauser'],
      ['BUCKETBLACK5GA','BUCKET-BLACK BUCKET 5GA',                 'EA', 3,     'Bucket Innovations',  nil],
      ['LID BLACK 5GA', 'LID-BLACK 5ga PAIL LID',                  'EA', 0.5,   'Bucket Innovations',  nil],
      ['BLKPOLYDR55',   'New Black Poly 55g Drum',                 'EA', 25,    'Greif',               nil],
      ['BLKPOLYDR30',   'New Black Poly 30g Drum',                 'EA', 20,    'Greif',               nil],
      ['WHTDRUM',       'DRUM-NEW WHITE POLY 55g',                 'EA', 25,    'Greif',               nil],
      ['NATDRUM',       'DRUM-NEW NATURAL POLY 55g',               'EA', 25,    'Greif',               nil],
      ['METHANOL',      'METHANOL',                                'GA', nil,   'Koch Methanol',       nil],
      ['PGBULK',        'PROPYLENE GLYCOL BULK',                   'GA', nil,   'Perry Brothers Oil',  nil],
      ['H60T',          'FG HTF METAL GUARD ADD',                  'GA', nil,   'Dober',               nil],
      ['POATCONC',      'POAT L288 YELLOW CONCENTRATE',            'GA', nil,   'Crucible Chemical',   nil],
      ['ALCOHOL',       'ALCOHOL BULK',                            'GA', nil,   'Koch Methanol',       nil],
      ['GLYCERIN',      'GLYCERINE BULK',                          'GA', nil,   'Perry Brothers Oil',  nil],
      ['PRA0L0',        'DEXCOOL CONCENTRATE',                     'GA', nil,   'COMPLEX SALES',       nil],
      ['DEFADDITV',     'DEF ADDITIVE',                            'GA', nil,   'Dober',               nil],
      ['UREA',          'UREA SOLUTION 32.5%',                     'GA', nil,   'COMPLEX SALES',       nil],
      ['DIWATER',       'DEIONIZED WATER',                         'GA', nil,   'Five Points Service', nil],
      ['1014111',       '275g Tote Suction Tube',                  'EA', 5,     'Blue 1 Energy',       nil],
      ['1014112',       '330g Tote Suction Tube',                  'EA', 5,     'Blue 1 Energy',       nil],
      ['1014113',       '55g Drum Suction Tube',                   'EA', 3,     'Blue 1 Energy',       nil],
    ]

    created = 0

    rows.uniq { |r| r[0].to_s }.each do |row|
      product_id     = row[0].to_s.strip
      primary_name   = row[4].to_s.strip.presence
      secondary_name = row[5].to_s.strip.presence

      product = Product.find_by(id: product_id)
      next unless product
      next if product.product_vendors.any?

      vendor_ids = [primary_name, secondary_name].compact.filter_map { |n| vendor_map[n] }
      next if vendor_ids.empty?

      product.set_vendors_in_order(vendor_ids)
      created += 1
    end

    redirect_to vendors_path, notice: "Vendor assignment complete — #{created} products updated. You can now remove this button."
  end

  private

  def set_vendor
    @vendor = Vendor.find(params[:id])
  end

  def vendor_params
    params.require(:vendor).permit(:name, :contact_name, :email, :phone, :lead_time_days,
                                   :address_1, :address_2, :city, :state, :zip, :payment_terms, :payment_method)
  end
end