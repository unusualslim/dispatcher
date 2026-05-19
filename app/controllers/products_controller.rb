class ProductsController < ApplicationController
  before_action :require_admin!
    before_action :set_product, only: %i[show edit update destroy components]
  
    def index
      @products = Product.order(:name)

      if params[:query].present?
        @products = @products.where("name ILIKE ?", "%#{params[:query]}%")
      end

      case params[:type]
      when 'raw'      then @products = @products.where(is_raw_material: true)
      when 'finished' then @products = @products.where(is_raw_material: false)
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
                  when 'stock_asc'  then @products.order(current_stock: :asc)
                  when 'stock_desc' then @products.order(current_stock: :desc)
                  when 'cost'       then @products.order(cost_per_unit: :desc)
                  else @products
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
          Product.where("name ILIKE ?", "%#{q}%")
                .order(:name)
                .limit(25)
        end

      render json: products.map { |p|
        {
          id: p.id,
          text: [p.name, (p.respond_to?(:sku) ? p.sku : nil)].compact.join(" — ")
        }
      }
    end

    def show
      @product.product_components.build if @product.product_components.empty?

      @recent_transactions = @product.inventory_transactions
                                     .order(created_at: :desc)
                                     .includes(:created_by)
                                     .limit(10)
      @open_purchase_orders = @product.purchase_orders
                                      .where(status: PurchaseOrder::STATUSES - %w[received cancelled])
                                      .includes(:vendor)
                                      .order(created_at: :desc)

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
        :cost_per_unit,
        :pdi_package_code,
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