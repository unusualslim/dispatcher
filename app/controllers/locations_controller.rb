class LocationsController < ApplicationController

    def index
        @locations = Location.all
    end

    def show
        @location = Location.find(params[:id])
    end

    def new
      @location = Location.new
    end

    def edit
      @location = Location.find(params[:id])
    end
  
    def create
      @location = Location.new(location_params)

      respond_to do |format|
        if @location.save
          format.html { redirect_to location_url(@location), notice: "Location was successfully created." }
          format.json { render :show, status: :created, location: @location }
        else
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: @location.errors, status: :unprocessable_entity }
        end
      end
    end

    def update
      @location = Location.find(params[:id])
    
      if @location.update(location_params)
        respond_to do |format|
          format.html { redirect_to @location, notice: 'Location was successfully updated.' }
          format.json { render :show, status: :ok, location: @location }
        end
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @location.errors, status: :unprocessable_entity }
      end
    end

    def destroy
        @location = Location.find(params[:id])
        if @location.destroy
          redirect_to locations_path, notice: 'Location was successfully deleted.'
        else
          redirect_to locations_path, alert: 'Failed to delete location.'
        end
    end
  
    private
  
    def location_params
      params.require(:location).permit(:city, :address, :location_category_id, :company_name, :phone_number, :state, :notes, :zip)
    end
end
