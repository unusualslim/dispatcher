module PdiMasterData
  # PDI fuel and warehouse products → products, by PDI item ID (= products.id). PDI's name, reporting
  # group, package code and active flag win; active new items are added. An item inactive in PDI only
  # has its app product marked inactive (nothing else changes) and is never added. Stock and costs are
  # left alone.
  class ProductSync < Sync
    SECTION = :products
    NODES = '//Products/FuelProducts/FuelProduct | //Products/WarehouseProducts/WarehouseProduct'.freeze

    def call
      nodes = @doc.xpath(NODES)
      @existing = Product.where(id: nodes.map { |node| text(node, 'ID') }).index_by(&:id)
      nodes.each do |node|
        id = text(node, 'ID')
        guard(id, text(node, 'Description')) { sync(id, node) } if id
      end
    end

    private

    def sync(id, node)
      attrs = product_attrs(node)
      return create(id, attrs, node) unless @existing[id]

      active = text(node, 'Active') == 'Yes'
      update(@existing[id], active ? attrs.merge(active: true) : { active: false }, node, attrs[:name])
    end

    def update(product, attrs, node, name)
      changes = diff(product, attrs)
      if apply? && changes.any?
        ensure_fuel_group(node, attrs[:category])
        product.update!(changes)
      end
      record(changes.any? ? :update : :unchanged, product.id, name, changes, attrs[:active] ? nil : 'Inactive in PDI')
    end

    def create(id, attrs, node)
      return record(:skip, id, attrs[:name], {}, 'Inactive in PDI') unless text(node, 'Active') == 'Yes'

      if apply?
        ensure_fuel_group(node, attrs[:category])
        Product.create!(attrs.merge(id: id, is_raw_material: raw_material?(attrs[:category])))
      end
      record(:create, id, attrs[:name], attrs)
    end

    # Fuel products have no package; warehouse products use their first one.
    def product_attrs(node)
      attrs = { name: text(node, 'Description'), category: text(node, 'ReportingGroup') }
      package = node.at_xpath('ProductPackage')
      return attrs.compact unless package

      code = text(package, 'PackageCode')
      attrs.merge(pdi_package_code: code, unit_of_measurement: code,
                  weight: text(package, 'RawPackageWeight')&.to_d).compact
    end

    # Product's after_save creates missing reporting groups as warehouse; fuel groups need item_type fuel.
    def ensure_fuel_group(node, category)
      return unless node.name == 'FuelProduct' && category.present?

      ReportingGroup.find_or_create_by!(name: category) { |group| group.item_type = 'fuel' }
    end

    def raw_material?(category)
      PdiProductImportService::RAW_MATERIAL_CATEGORIES.any? { |c| category.to_s.start_with?(c) }
    end
  end
end
