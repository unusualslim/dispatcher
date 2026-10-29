# Adds and removes a freight table's rows, one at a time or pasted in bulk (import).
class FreightTableRatesController < ApplicationController
  permission_area :sales
  before_action :set_table

  def create
    rate = @table.rates.build(rate_params)
    if rate.save
      redirect_to freight_table_path(@table), notice: t('.created')
    else
      redirect_to freight_table_path(@table), alert: rate.errors.full_messages.to_sentence
    end
  end

  def destroy
    @table.rates.find(params[:id]).destroy!
    redirect_to freight_table_path(@table), notice: t('.deleted')
  end

  # Pasted rows: mileage "from, to, rate" (blank "to" = and over); point to point "origin, destination, rate"
  # with location IDs or exact names (blank origin = from anywhere); flat "rate". Replaces the table's rows.
  def import
    result = Freight::TableImport.new(@table, params[:rows].to_s).call
    if result.errors.any?
      redirect_to freight_table_path(@table), alert: result.errors.first(5).join(' ')
    else
      redirect_to freight_table_path(@table), notice: t('.imported', count: result.imported)
    end
  end

  private

  def set_table
    @table = FreightTable.find(params[:freight_table_id])
  end

  def rate_params
    params.require(:freight_table_rate).permit(:origin_location_id, :destination_location_id, :miles_from,
                                               :miles_to, :rate)
  end
end
