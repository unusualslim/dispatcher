class PhoneNumbersController < ApplicationController
    before_action :set_phone_number, only: [:destroy]
  
    def destroy
      if @phone_number.destroy
        respond_to do |format|
          format.json { head :no_content }
          format.html { redirect_to edit_customer_path(@phone_number.customer), notice: "Phone number removed." }
        end
      else
        respond_to do |format|
          format.json { render json: @phone_number.errors, status: :unprocessable_entity }
          format.html { redirect_back fallback_location: root_path, alert: "Failed to remove phone number." }
        end
      end
    end
  
    private
  
    def set_phone_number
      @phone_number = PhoneNumber.find(params[:id])
    end
  end  