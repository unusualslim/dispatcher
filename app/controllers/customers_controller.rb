class CustomersController < ApplicationController
  include CsvRoundTrip
  include RemembersListFilters
  permission_area :sales, lookups: %i[search select2]
  before_action :set_customer, only: %i[edit update destroy]

  # GET /customers
  def index
    return if restore_list_filters('customers', CustomerListQuery::KEYS)

    @states = Location.where(id: CustomerLocation.select(:location_id)).where.not(state: [nil, ''])
                      .distinct.order(:state).pluck(:state)
    @customers = CustomerListQuery.new(params).relation.includes(:locations)
                                  .paginate(page: params[:page], per_page: 50)
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
    @customer.phone_numbers.build if @customer.phone_numbers.empty? # Initialize phone numbers if none exist
  end

  # PATCH/PUT /customers/:id
  def update
    Rails.logger.debug { "Updating customer with params: #{params.inspect}" }
    @customer = Customer.find(params[:id])

    if @customer.update(customer_params)
      Rails.logger.debug('Successfully updated customer')
      redirect_to @customer, notice: 'Customer was successfully updated.'
    else
      Rails.logger.debug('Failed to update customer')
      render :edit
    end
  end

  # DELETE /customers/:id
  def destroy
    @customer.destroy
    redirect_to customers_path, notice: 'Customer was successfully deleted.'
  end

  # Lazy-loaded Turbo Frame: the customer's live credit position from PDI (?amount= compares an order total).
  def pdi_credit
    @customer = Customer.find(params[:id])
    @amount = params[:amount].presence&.to_d
    fetch_pdi_credit if @customer.pdi_customer_id.present? && PdiWebService.configured?
    render partial: 'customers/pdi_credit', layout: false
  end

  def search
    @customers = if params[:query].present?
                   Customer.joins(:phone_numbers)
                           .where('phone_numbers.number LIKE ?', "%#{params[:query]}%")
                           .distinct
                 else
                   Customer.none
                 end
    render :search # Or a specific view for search results
  end

  def select2
    term = params[:q].to_s.strip

    customers = Customer.active.order(:name).limit(25)
    customers = customers.where('LOWER(name) LIKE ?', "%#{term.downcase}%") if term.present?

    render json: customers.map { |c| { id: c.id, text: c.name } }
  end

  private

  # Live credit check; also refreshes the customer's saved snapshot (dispatch board badge).
  def fetch_pdi_credit
    @credit = PdiWebService.new(read_timeout: 15).credit_check(@customer.pdi_customer_id)
    @customer.record_pdi_credit!(@credit.snapshot)
  rescue PdiWebService::Error, Net::OpenTimeout, Net::ReadTimeout, SocketError => e
    @error = e.message
  end

  def set_customer
    @customer = Customer.find(params[:id])
  end

  def customer_params
    params.require(:customer).permit(:name, :email, :phone, :preferred_contact_method, :active, :lead_time_days, location_ids: [],
                                                                                                                 phone_numbers_attributes: %i[id number _destroy])
  end

  def csv_resource
    Customer
  end

  def csv_columns
    [
      { attr: :id,                       header: 'ID',                       readonly: true  },
      { attr: :name,                     header: 'Name',                     readonly: false },
      { attr: :email,                    header: 'Email',                    readonly: false },
      { attr: :phone,                    header: 'Phone',                    readonly: false },
      { attr: :preferred_contact_method, header: 'Preferred Contact Method', readonly: false }
    ]
  end
end
