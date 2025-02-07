class VendorsController < ApplicationController
  before_action :set_vendor, only: [:destroy]

  def index
    @vendors = Vendor.all
    @vendor = Vendor.new  # For the form
  end

  def show
    @vendor = Vendor.find(params[:id])
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
    params.require(:vendor).permit(:name)
  end
end