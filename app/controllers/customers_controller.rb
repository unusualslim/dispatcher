class CustomersController < ApplicationController
    before_action :set_customer, only: [:edit, :update, :destroy]
  
    # GET /customers
    def index
      @customers = Customer.all
    end

    def show
        @customer = Customer.find(params[:id])
    end
  
    # GET /customers/new
    def new
      @customer = Customer.new
    end
  
    # POST /customers
    def create
        @customer = Customer.new(customer_params)
        if @customer.save
          redirect_to @customer, notice: 'Customer was successfully created.'
        else
          render :new
        end
      end
  
    # GET /customers/:id/edit
    def edit
    end
  
    # PATCH/PUT /customers/:id
    def update
        @customer = Customer.find(params[:id])
        if @customer.update(customer_params)
          redirect_to @customer, notice: 'Customer was successfully updated.'
        else
          render :edit
        end
      end
  
    # DELETE /customers/:id
    def destroy
      @customer.destroy
      redirect_to customers_path, notice: 'Customer was successfully deleted.'
    end
  
    private
  
    def set_customer
      @customer = Customer.find(params[:id])
    end
  
    def customer_params
      params.require(:customer).permit(:name, :email, :phone, :preferred_contact_method, location_ids: [])
    end
end  