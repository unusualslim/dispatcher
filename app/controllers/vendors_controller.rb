class VendorsController < ApplicationController
  before_action :require_admin!
  before_action :set_vendor, only: [:show, :edit, :update, :destroy]

  def index
    @vendors = Vendor.all
    @vendor = Vendor.new  # For the form
  end

  def show
  end

  def edit
  end

  def update
    if @vendor.update(vendor_params)
      redirect_to @vendor, notice: "Vendor updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def create
    @vendor = Vendor.new(vendor_params)
    if @vendor.save
      redirect_to vendors_path, notice: "Vendor successfully added."
    else
      @vendors = Vendor.all
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @vendor.destroy
    redirect_to vendors_path, notice: "Vendor successfully deleted."
  end

  private

  def set_vendor
    @vendor = Vendor.find(params[:id])
  end

  def vendor_params
    params.require(:vendor).permit(:name, :contact_name, :email, :phone, :lead_time_days,
                                   :address_1, :address_2, :city, :state, :zip, :payment_terms, :payment_method)
  end
end