class CustomersController < ApplicationController
    before_action :set_customer, only: [:edit, :update, :destroy]
  
    # GET /customers
    def index
      if params[:search].present?
        @customers = Customer.where("name LIKE ?", "%#{params[:search]}%")
      elsif params[:sort] == 'name'
        @customers = Customer.order(:name)
      else
        @customers = Customer.all
      end
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
      @customer = Customer.find(params[:id])
      @customer.phone_numbers.build if @customer.phone_numbers.empty?  # Initialize phone numbers if none exist
    end
  
    # PATCH/PUT /customers/:id
    def update
      Rails.logger.debug("Updating customer with params: #{params.inspect}")
      @customer = Customer.find(params[:id])
      
      if @customer.update(customer_params)
        Rails.logger.debug("Successfully updated customer")
        redirect_to @customer, notice: 'Customer was successfully updated.'
      else
        Rails.logger.debug("Failed to update customer")
        render :edit
      end
    end    
  
    # DELETE /customers/:id
    def destroy
      @customer.destroy
      redirect_to customers_path, notice: 'Customer was successfully deleted.'
    end

    def search
      if params[:query].present?
        @customers = Customer.joins(:phone_numbers)
                             .where('phone_numbers.number LIKE ?', "%#{params[:query]}%")
                             .distinct
      else
        @customers = Customer.none
      end
      render :search # Or a specific view for search results
    end

    def select2
      term = params[:q].to_s.strip

      customers =
        if term.present?
          Customer.where("LOWER(name) LIKE ?", "%#{term.downcase}%").order(:name).limit(25)
        else
          Customer.order(:name).limit(25)
        end

      render json: customers.map { |c| { id: c.id, text: c.name } }
    end

  
    private
  
    def set_customer
      @customer = Customer.find(params[:id])
    end
  
    def customer_params
      params.require(:customer).permit(:name, :email, :phone, :preferred_contact_method, location_ids: [], phone_numbers_attributes: [:id, :number, :_destroy])
    end
end  