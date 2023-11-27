class CustomerOrdersController < ApplicationController

    def index
        @customer_orders = CustomerOrder.all
    end

    def show
        @customer_order = CustomerOrder.find(params[:id])
    end

    def new
        @customer_order = CustomerOrder.new
    end

    def edit
        @customer_order = CustomerOrder.find(params[:id])
    end

    def create
        @customer_order = CustomerOrder.new(customer_order_params)
    
        respond_to do |format|
          if @customer_order.save
            format.html { redirect_to customer_order_url(@customer_order), notice: "Order was successfully created." }
            format.json { render :show, status: :created, location: @customer_order }
          else
            format.html { render :new, status: :unprocessable_entity }
            format.json { render json: @customer_order.errors, status: :unprocessable_entity }
          end
        end
    end

    def update

    end

    def destroy

    end

    private
    def customer_order_params
      params.require(:customer_order).permit(:required_delivery_date, :product, :location_id, :approximate_product_amount, :notes, :order_status)
    end
end
