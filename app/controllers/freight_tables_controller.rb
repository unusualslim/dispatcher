# A freight index table (point to point, mileage or flat) and its rates. Listed on Freight Rules → Tables.
class FreightTablesController < ApplicationController
  permission_area :sales
  before_action :set_table, only: %i[show edit update destroy]

  def show
    @rates = @table.rates.includes(:origin_location, :destination_location)
    @rates = @rates.sort_by { |r| [r.destination_location&.company_name.to_s, r.origin_location&.company_name.to_s] } if
      @table.lookup_type == 'point_to_point'
    @locations = Location.order(:company_name).select(:id, :company_name, :city)
    @rules = @table.freight_rules.ordered
  end

  def new
    @table = FreightTable.new(lookup_type: params[:lookup_type].presence || 'mileage')
  end

  def edit; end

  def create
    @table = FreightTable.new(table_params)
    if @table.save
      redirect_to freight_table_path(@table), notice: t('.created', name: @table.name)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @table.update(table_params)
      redirect_to freight_table_path(@table), notice: t('.updated', name: @table.name)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @table.destroy
      redirect_to freight_rules_path(tab: 'tables'), notice: t('.deleted', name: @table.name)
    else
      redirect_to freight_table_path(@table), alert: @table.errors.full_messages.to_sentence
    end
  end

  private

  def set_table
    @table = FreightTable.find(params[:id])
  end

  def table_params
    params.require(:freight_table).permit(:name, :lookup_type, :notes)
  end
end
