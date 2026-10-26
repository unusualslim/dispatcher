module Mrp
  # Products MRP plans: active raw materials and warehouse items (fuel tanks are tracked by the FI
  # inventory report), plus anything used in their BOMs, at any depth, such as bulk DEF in DEF jugs.
  class Scope
    def products
      ids = with_components(base_ids)
      Product.where(id: ids).includes(:reporting_group, product_vendors: :vendor).index_by(&:id)
    end

    # Product ID → [[component ID, quantity per unit]] for the planned products.
    def boms(ids)
      ProductComponent.where(product_id: ids).pluck(:product_id, :component_product_id, :quantity_per_unit)
                      .group_by(&:first).transform_values { |rows| rows.map { |_, c, qty| [c, qty.to_d] } }
    end

    private

    def base_ids
      products = Product.active.left_joins(:reporting_group)
      products.where(is_raw_material: true).or(products.where(reporting_groups: { item_type: [nil, 'warehouse'] }))
              .pluck(:id)
    end

    def with_components(ids)
      all = ids.to_set
      frontier = ids
      while frontier.any?
        frontier = ProductComponent.where(product_id: frontier).pluck(:component_product_id)
                                   .reject { |id| all.include?(id) }
        all.merge(frontier)
      end
      all.to_a
    end
  end
end
