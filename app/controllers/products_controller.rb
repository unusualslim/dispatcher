class ProductsController < ApplicationController
  include CsvRoundTrip
  include RemembersListFilters
  include ListNeighbors
  permission_area :inventory, lookups: %i[search bom]
  before_action :set_product, only: %i[show edit update destroy components]

  def index
    return if restore_list_filters('products', ProductListQuery::KEYS)

    list = ProductListQuery.new(params, warehouse: current_warehouse)
    @selected_categories = list.categories
    @categories = Product.where.not(category: [nil, '']).distinct.order(:category).pluck(:category)
    @units = Product.where.not(unit_of_measurement: [nil, '']).distinct.order(:unit_of_measurement)
                    .pluck(:unit_of_measurement)
    @products = list.relation.paginate(page: params[:page], per_page: 50)

    # Preload on_order and committed aggregates in two bulk queries to avoid N+1
    product_ids = @products.map(&:id)

    on_order_map = PurchaseOrderLineItem
                   .joins(:purchase_order)
                   .where(product_id: product_ids)
                   .where(purchase_orders: { status: %w[draft pending_approval approved submitted] })
                   .group(:product_id)
                   .sum(:quantity)

    committed_map = ProductionOrderComponent
                    .joins(:production_order)
                    .where(product_id: product_ids)
                    .where(production_orders: { status: ProductionOrder::OPEN_STATUSES })
                    .group(:product_id)
                    .sum(:quantity)

    bom_map = ProductComponent
              .where(product_id: product_ids)
              .includes(component_product: :standard_cost_histories)
              .group_by(&:product_id)
    cost_line_map = ProductCostLine.where(product_id: product_ids).includes(:reporting_group, :cost_item)
                                   .order(:position, :id).group_by(&:product_id)

    @products.each do |p|
      p.instance_variable_set(:@on_order_qty,  on_order_map[p.id]  || 0)
      p.instance_variable_set(:@committed_qty, committed_map[p.id] || 0)
      p.instance_variable_set(:@bom_lines,     bom_map[p.id]       || [])
      p.instance_variable_set(:@cost_lines,    cost_line_map[p.id] || [])
    end
  end

  def new
    @product = Product.new(unit_of_measurement: 'Each')
    @vendors = Vendor.order(:name)
  end

  def create
    @product = Product.new(product_params)
    if @product.save
      @product.set_vendors_in_order(params[:product][:vendor_ids])
      redirect_to products_path, notice: 'Product was successfully added.'
    else
      @vendors = Vendor.order(:name)
      render :new
    end
  end

  def edit
    @vendors = Vendor.order(:name)
  end

  def update
    if @product.update(product_params)
      @product.set_vendors_in_order(params[:product][:vendor_ids])
      redirect_to product_path(@product), notice: 'Product was successfully updated.'
    else
      @vendors = Vendor.order(:name)
      @product.product_components.build if @product.product_components.empty?
      load_show_data
      render :show, status: :unprocessable_entity
    end
  end

  def destroy
    @product.destroy
    redirect_to products_path, notice: 'Product was successfully deleted.'
  end

  def search
    q = params[:q].to_s.strip
    products =
      if q.blank?
        Product.active.order(:name).limit(25)
      else
        Product.active.where('name ILIKE ? OR id ILIKE ?', "%#{q}%", "%#{q}%")
               .order(Arel.sql(<<~SQL.squish))
                 CASE
                   WHEN name ILIKE #{ActiveRecord::Base.connection.quote(q)}        THEN 0
                   WHEN id   ILIKE #{ActiveRecord::Base.connection.quote(q)}        THEN 0
                   WHEN name ILIKE #{ActiveRecord::Base.connection.quote("#{q}%")}  THEN 1
                   ELSE 2
                 END, name
               SQL
               .limit(25)
      end

    render json: products.map { |p|
      { id: p.id, text: "#{p.name} (#{p.id})" }
    }
  end

  def show
    @product.product_components.build if @product.product_components.empty?
    load_show_data
    find_list_neighbors(@product, ProductListQuery.new(remembered_list_params('products'), warehouse: current_warehouse)
                                                  .relation.pluck('products.id').uniq,
                        fallback: -> { Product.order(:name, :id).pluck(:id) })

    respond_to do |format|
      format.html
      format.json do
        render json: {
          id: @product.id,
          name: @product.name,
          sku: (@product.respond_to?(:sku) ? @product.sku : nil)
        }
      end
    end
  end

  def components
    rows = @product.product_components.includes(:component_product).map do |pc|
      {
        id: pc.id,
        component_product_id: pc.component_product_id,
        component_name: pc.component_product&.name,
        quantity_per_unit: pc.quantity_per_unit&.to_f,
        uom: pc.uom
      }
    end

    render json: { product_id: @product.id, components: rows }
  end

  def bom
    product = Product.includes(product_components: :component_product).find(params[:id])

    components = product.product_components.map do |pc|
      cp = pc.component_product
      {
        id: cp.id,
        name: cp.name,
        part_number: cp.id,
        quantity_per_unit: pc.quantity_per_unit,
        uom: pc.uom
      }
    end

    render json: { components: components }
  end

  private

  def set_product
    @product = Product.find(params[:id])
  end

  def load_show_data
    @product_vendors = @product.product_vendors.includes(:vendor)
    @recent_transactions = @product.inventory_transactions
                                   .order(created_at: :desc)
                                   .includes(:created_by)
                                   .limit(10)
    @open_purchase_orders = @product.purchase_orders
                                    .where(status: PurchaseOrder::STATUSES - %w[received cancelled voided])
                                    .includes(:vendor, :line_items)
                                    .order(created_at: :desc)
    @standard_cost_histories = @product.standard_cost_histories.includes(:created_by)
  end

  def product_params
    params.require(:product).permit(
      :id,
      :name,
      :description,
      :price,
      :unit_of_measurement,
      :weight,
      :is_raw_material,
      :active,
      :lead_time_days,
      :production_days,
      :current_stock,
      :reorder_point,
      :safety_stock,
      :max_stock,
      :cost_per_unit,
      :standard_cost,
      :pdi_package_code,
      :pdi_tank_id,
      :category,
      :pdi_repack_fee,
      :coa_note,
      :freight_class_id,
      product_components_attributes: %i[
        id
        component_product_id
        quantity_per_unit
        uom
        _destroy
      ],
      quality_specs_attributes: %i[id section name test_method result_type expected unit target_min target_max position
                                   _destroy],
      product_cost_lines_attributes: %i[
        id
        cost_item_id
        description
        reporting_group_id
        quantity
        unit_cost
        per_quantity
        position
        _destroy
      ]
    )
  end

  def csv_resource
    Product
  end

  def csv_after_update(record, attrs)
    return unless attrs.key?(:standard_cost)

    record.standard_cost_histories.create!(
      amount: attrs[:standard_cost],
      effective_date: Date.today,
      created_by: current_user
    )
  end

  def csv_columns
    [
      { attr: :id,                  header: 'ID',               readonly: true  },
      { attr: :name,                header: 'Name',             readonly: true  },
      { attr: :unit_of_measurement, header: 'Unit',             readonly: false },
      { attr: :cost_per_unit,       header: 'Cost/Unit',        readonly: false },
      { attr: :standard_cost,       header: 'Standard Cost',    readonly: false },
      { attr: :pdi_repack_fee,      header: 'PDI Repack Fee',   readonly: false },
      { attr: :reorder_point,       header: 'Reorder Point',    readonly: false },
      { attr: :safety_stock,        header: 'Safety Stock',     readonly: false },
      { attr: :max_stock,           header: 'Max Stock',        readonly: false },
      { attr: :pdi_package_code,    header: 'PDI Package Code', readonly: false },
      { attr: :pdi_tank_id,         header: 'PDI Tank ID',      readonly: false }
    ]
  end
end
