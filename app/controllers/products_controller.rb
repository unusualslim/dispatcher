class ProductsController < ApplicationController
    before_action :set_product, only: %i[edit update destroy]
  
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
        render :edit
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

  
    private
  
    def set_product
      @product = Product.find(params[:id])
    end
  
    def product_params
      params.require(:product).permit(:name, :description, :price, :unit_of_measurement, :weight)
    end
  end