# One-time load from PDI's FI Fuel Costs report (Terminal Products.XLS, costs as of 2026-11-20): a terminal carries a
# product when the report has a cost above 0 for it there. Links each matched origin location to its PDI terminal ID
# and adds the products it carries as (zero-stock) location products, which is where the suggested-load builder looks
# for terminals by product. Site 0002 (Five Points Service - Main) is a 901 source too; it already has its 901 row.
# Left out: pricing-only terminals (1, 100, 80, 81, 90, 92, NOLA), the "Delivered" prices (DELRAIL, DELIMM, DELJAX,
# DELDOT, DELVAL) and terminals with no app location (MANFV, NUTLIM, AC Gas, Partners Propane).
# Locations are matched by id + name (production ids), so other databases skip what they don't have.
class LoadTerminalProducts < ActiveRecord::Migration[8.1]
  class Location < ActiveRecord::Base
    self.table_name = 'locations'
  end

  class LocationProduct < ActiveRecord::Base
    self.table_name = 'location_products'
  end

  # [location id, name in the app, PDI terminal ID, products]
  TERMINALS = [
    [7, 'Nutrien - Augusta', 'NUTAUG', %w[901]],
    [234, 'Musket - Morrow', 'MUSMOR', %w[901]],
    [217, 'Musket - Orlando', 'MUSORL', %w[901]],
    [19, 'Blue Sky DEF - Fort Pierce', 'BLUFTP', %w[901]],
    [235, 'Tartan', 'TARCAM', %w[901]],
    [20, 'Tartan/Saratoga DEF', 'TAROCA', %w[901]],
    [219, 'Yara Tampa', 'YARTAM', %w[901]],
    [226, 'CF Industries', 'CFIDON', %w[ULQ50]],
    [441, 'Five Points Service - Main', nil, %w[901]]
  ].freeze

  def up
    TERMINALS.each do |id, name, terminal_id, products|
      location = Location.find_by(id: id, company_name: name)
      next say("Skipped #{name} (#{id}): not in this database") unless location

      link(location, terminal_id) if terminal_id
      products.each { |product_id| add_product(location, product_id) }
    end
  end

  def down; end

  private

  def link(location, terminal_id)
    return if location.pdi_terminal_id == terminal_id

    holder = Location.find_by(pdi_terminal_id: terminal_id)
    return say("#{terminal_id} already on location #{holder.id}; #{location.company_name} left unlinked") if holder
    return say("#{location.company_name} already linked to #{location.pdi_terminal_id}") if location.pdi_terminal_id

    location.update_columns(pdi_terminal_id: terminal_id, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    say "#{location.company_name} → #{terminal_id}"
  end

  def add_product(location, product_id)
    return if LocationProduct.exists?(location_id: location.id, product_id: product_id)
    return say("Product #{product_id} missing; not added at #{location.company_name}") unless
      connection.select_value("SELECT 1 FROM products WHERE id = #{connection.quote(product_id)}")

    LocationProduct.create!(location_id: location.id, product_id: product_id)
    say "#{location.company_name} carries #{product_id}"
  end
end
