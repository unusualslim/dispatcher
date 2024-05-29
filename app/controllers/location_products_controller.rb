class LocationProductsController < ApplicationController
    before_action :set_location
    before_action :set_location_product, only: [:edit, :update, :destroy]
    before_action :set_products, only: [:new, :edit]
  
    def new
      @location_product = @location.location_products.build
    end
  
    def create
      @location_product = @location.location_products.build(location_product_params)
      if @location_product.save
        redirect_to @location, notice: 'Product was successfully added to the location.'
      else
        render :new
      end
    end
  
    def edit
    end
  
    def update
      if @location_product.update(location_product_params)
        redirect_to @location, notice: 'Product was successfully updated.'
      else
        render :edit
      end
    end
  
    def destroy
      @location_product.destroy
      redirect_to @location, notice: 'Product was successfully removed from the location.'
    end
  
    private
  
    def set_location
      @location = Location.find(params[:location_id])
    end
  
    def set_location_product
      @location_product = @location.location_products.find(params[:id])
    end
  
    def set_products
      @products = Product.all
    end
  
    def location_product_params
      params.require(:location_product).permit(:product_id, :max_capacity, :uleage_90, :cutoff)
    end
  end
  