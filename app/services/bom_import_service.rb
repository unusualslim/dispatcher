require 'csv'

class BomImportService
  # Package priority for selecting the primary BOM when a product has multiple package codes
  PKG_PRIORITY = %w[EA 55GA 5GA GA].freeze

  COL_FINISHED_ID   = 0
  COL_FINISHED_NAME = 1
  COL_FINISHED_PKG  = 2
  COL_COMPONENT_ID  = 3
  COL_COMPONENT_PKG = 5
  COL_QUANTITY      = 6

  Result      = Struct.new(:created, :overwritten, :skipped_no_product, :skipped_already_has_bom, :errors, keyword_init: true)
  PreviewRow  = Struct.new(:finished_id, :finished_name, :product, :action, :pkg_code, :components, keyword_init: true)
  ComponentPreview = Struct.new(:component_id, :component_name, :component_product, :quantity, :uom, keyword_init: true)

  def self.call(file_path, overwrite: false)
    new(file_path, overwrite: overwrite).run
  end

  def initialize(file_path, overwrite: false)
    @file_path = file_path
    @overwrite = overwrite
  end

  def preview
    rows = CSV.read(@file_path, headers: false, encoding: 'bom|utf-8')
    rows = rows[1..] if rows.first&.first.to_s.strip == 'FinishedProductID'
    by_product = rows.group_by { |r| r[COL_FINISHED_ID].to_s.strip }

    by_product.map do |finished_id, product_rows|
      finished_name = product_rows.first[COL_FINISHED_NAME].to_s.strip
      product = Product.find_by(id: finished_id)

      unless product
        next PreviewRow.new(finished_id: finished_id, finished_name: finished_name, product: nil,
                            action: :skip_no_product, pkg_code: nil, components: [])
      end

      if product.product_components.any? && !@overwrite
        next PreviewRow.new(finished_id: finished_id, finished_name: finished_name, product: product,
                            action: :skip_has_bom, pkg_code: nil, components: [])
      end

      by_pkg = product_rows.group_by { |r| r[COL_FINISHED_PKG].to_s.strip }
      chosen_pkg = PKG_PRIORITY.find { |pkg| by_pkg.key?(pkg) } || by_pkg.keys.first
      chosen_rows = by_pkg[chosen_pkg]

      components = chosen_rows.map do |row|
        component_id  = row[COL_COMPONENT_ID].to_s.strip
        component_pkg = row[COL_COMPONENT_PKG].to_s.strip
        quantity      = row[COL_QUANTITY].to_f
        comp = Product.find_by(id: component_id)
        ComponentPreview.new(component_id: component_id,
                             component_name: comp&.name || '(not found in system)',
                             component_product: comp,
                             quantity: quantity,
                             uom: component_pkg.presence || 'EA')
      end

      action = product.product_components.any? ? :overwrite : :create
      PreviewRow.new(finished_id: finished_id, finished_name: finished_name, product: product,
                     action: action, pkg_code: chosen_pkg, components: components)
    end.compact
  end

  def run
    result = Result.new(created: 0, overwritten: 0, skipped_no_product: 0, skipped_already_has_bom: 0, errors: [])

    rows = CSV.read(@file_path, headers: false, encoding: 'bom|utf-8')
    rows = rows[1..] if rows.first&.first.to_s.strip == 'FinishedProductID'

    # Group by finished_product_id → pkg_code → [rows]
    by_product = rows.group_by { |r| r[COL_FINISHED_ID].to_s.strip }

    by_product.each do |finished_id, product_rows|
      product = Product.find_by(id: finished_id)
      unless product
        result.skipped_no_product += 1
        result.errors << "Finished product #{finished_id} (#{product_rows.first[COL_FINISHED_NAME]}) not found in LoadNTrucks — skipped"
        next
      end

      if product.product_components.any?
        if @overwrite
          product.product_components.destroy_all
          result.overwritten += 1
        else
          result.skipped_already_has_bom += 1
          next
        end
      end

      # Group by package code, then pick primary package
      by_pkg = product_rows.group_by { |r| r[COL_FINISHED_PKG].to_s.strip }
      chosen_pkg = PKG_PRIORITY.find { |pkg| by_pkg.key?(pkg) } || by_pkg.keys.first
      chosen_rows = by_pkg[chosen_pkg]

      chosen_rows.each do |row|
        component_id  = row[COL_COMPONENT_ID].to_s.strip
        component_pkg = row[COL_COMPONENT_PKG].to_s.strip
        quantity      = row[COL_QUANTITY].to_f

        component = Product.find_by(id: component_id)
        unless component
          result.errors << "#{finished_id}: component #{component_id} not found in LoadNTrucks — skipped"
          next
        end

        ProductComponent.create!(
          product:           product,
          component_product: component,
          quantity_per_unit: quantity,
          uom:               component_pkg.presence || 'EA'
        )
        result.created += 1
      end
    rescue => e
      result.errors << "Product #{finished_id}: #{e.message}"
    end

    result
  end
end
