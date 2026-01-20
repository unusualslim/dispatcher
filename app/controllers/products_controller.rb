class ProductsController < ApplicationController
    before_action :set_product, only: %i[edit update destroy, :components]
  
    def index
      @products = Product.all
    end
  
    def new
      @product = Product.new
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
      @product = Product.find(params[:id])

      # ensure at least one row renders in the HTML form
      @product.product_components.build if @product.product_components.empty?

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
          part_number: (cp.respond_to?(:sku) ? cp.sku : nil),
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
        :name,
        :description,
        :price,
        :unit_of_measurement,
        :weight,
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