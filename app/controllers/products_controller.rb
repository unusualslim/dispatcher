class ProductsController < ApplicationController
  before_action :require_admin!
    before_action :set_product, only: %i[show edit update destroy components]
  
    def index
      @products = Product.all
      @categories = Product.where.not(category: [nil, '']).distinct.order(:category).pluck(:category)

      if params[:query].present?
        @products = @products.where("name ILIKE ? OR id ILIKE ?", "%#{params[:query]}%", "%#{params[:query]}%")
      end

      case params[:type].presence || 'finished'
      when 'raw'      then @products = @products.where(is_raw_material: true)
      when 'finished' then @products = @products.where(is_raw_material: false)
      # 'all' — no filter
      end

      if params[:category].present?
        @products = @products.where(category: params[:category])
      end

      case params[:status]
      when 'critical'
        @products = @products.where("reorder_point IS NOT NULL AND current_stock <= COALESCE(safety_stock, 0)")
      when 'low'
        @products = @products.where("reorder_point IS NOT NULL AND current_stock > COALESCE(safety_stock, 0) AND current_stock <= reorder_point")
      when 'ok'
        @products = @products.where("reorder_point IS NOT NULL AND current_stock > reorder_point")
      end

      @products = case params[:sort]
                  when 'stock_asc'      then @products.order(current_stock: :asc)
                  when 'stock_desc'     then @products.order(current_stock: :desc)
                  when 'cost'           then @products.order(cost_per_unit: :desc)
                  when 'category_asc'   then @products.order(Arel.sql("COALESCE(category, '') ASC, name ASC"))
                  when 'category_desc'  then @products.order(Arel.sql("COALESCE(category, '') DESC, name ASC"))
                  else @products.order(:name)
                  end
    end
  
    def new
      @product = Product.new(unit_of_measurement: 'Each')
    end
  
    def create
      @product = Product.new(product_params)
      if @product.save
        redirect_to products_path, notice: 'Product was successfully added.'
      else
        render :new
      end
    end
  
    def edit
    end
  
    def update
      if @product.update(product_params)
        redirect_to products_path, notice: 'Product was successfully updated.'
      else
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
          Product.order(:name).limit(25)
        else
          Product.where("name ILIKE ? OR id ILIKE ?", "%#{q}%", "%#{q}%")
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
      @recent_transactions = @product.inventory_transactions
                                     .order(created_at: :desc)
                                     .includes(:created_by)
                                     .limit(10)
      @open_purchase_orders = @product.purchase_orders
                                      .where(status: PurchaseOrder::STATUSES - %w[received cancelled])
                                      .includes(:vendor, :line_items)
                                      .order(created_at: :desc)
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
        :current_stock,
        :reorder_point,
        :safety_stock,
        :max_stock,
        :cost_per_unit,
        :pdi_package_code,
        :category,
        product_components_attributes: [
          :id,
          :component_product_id,
          :quantity_per_unit,
          :uom,
          :_destroy
        ]
      )
    end
  end