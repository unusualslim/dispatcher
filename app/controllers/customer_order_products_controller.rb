class CustomerOrderProductsController < ApplicationController
    before_action :set_customer_order
  
    # Create a new product for a customer order
    def create
      @customer_order_product = @customer_order.customer_order_products.new(customer_order_product_params)
    
      if @customer_order_product.save
        redirect_to @customer_order, notice: 'Product was successfully added.'
      else
        flash[:alert] = 'There was an error adding the product.'
        redirect_to @customer_order  # Redirect to the customer order show page on failure
      end
    end
    
  
    # Update an existing product in a customer order
    def update
        @customer_order_product = CustomerOrderProduct.find(params[:id])
        if @customer_order_product.update(customer_order_product_params)
          redirect_to customer_order_path(@customer_order_product.customer_order), notice: 'Product updated successfully.'
        else
          render :edit
        end
      end
  
    # Remove a product from a customer order
    def destroy
      @customer_order_product = CustomerOrderProduct.find(params[:id])
      @customer_order_product.destroy
  
      redirect_to @customer_order, notice: 'Product removed from order successfully.'
    end
  
    private
  
    # Find the associated customer order
    def set_customer_order
      @customer_order = CustomerOrder.find(params[:customer_order_id])
    end
  
    # Strong parameters for customer order products
    def customer_order_product_params
      params.require(:customer_order_product).permit(:product_id, :quantity, :price)
    end
  end  