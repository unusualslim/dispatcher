class PopulateProductPartNumbers < ActiveRecord::Migration[7.0]
  PDI_MAPPING = {
     1 => "FPS001",
     2 => "FPS008",
     3 => "FPS009",
     4 => "FPS010",
     5 => "FPS011",
     6 => "FPS012",
     8 => "FPS002",
     9 => "7910901",
    10 => "VV891007",
    11 => "CC2826",
    12 => "CC2745",
    13 => "041FIBTWSHER187",
    14 => "FPS005",
    15 => "FPS099",
    16 => "CC360570",
    17 => "1000155",
    18 => "33001",
    19 => "27501",
    20 => "CC36074B",
    21 => "EGBULK",
    24 => "6525566901",
    25 => "6524565901",
    27 => "226606",
    28 => "022BBCJ00DEF088",
    30 => "5050",
    31 => "5030",
    33 => "921709000001",
    37 => "022BBCJ00DEF150",
    38 => "015AFFXALLSN077",
    39 => "BLUE LEAF 96207",
    40 => "10090055",
    41 => "022BBCJ00DEF086",
    43 => "7574901",
    44 => "041FIBTWSHER083",
    45 => "844501000007",
    48 => "METHANOL",
    49 => "BADEF2.5",
    50 => "FPS006",
    51 => "S3G",
  }.freeze

  def up
    PDI_MAPPING.each do |int_id, pdi_id|
      execute "UPDATE products SET part_number = #{connection.quote(pdi_id)} WHERE id = #{int_id}"
    end

    missing = execute("SELECT id, name FROM products WHERE part_number IS NULL OR part_number = ''").to_a
    raise "Products missing part_number after populate: #{missing.inspect}" if missing.any?

    add_index :products, :part_number, unique: true unless index_exists?(:products, :part_number)

    say "part_number populated for #{PDI_MAPPING.size} products."
  end

  def down
    remove_index :products, :part_number, if_exists: true
    execute "UPDATE products SET part_number = NULL"
  end
end
