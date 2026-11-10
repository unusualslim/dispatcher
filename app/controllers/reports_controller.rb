# The Reports hub: every report in Reports::Registry the user's areas can see, each with filters, totals,
# CSV export and print.
class ReportsController < ApplicationController
  before_action :require_any_access!
  before_action :set_report, only: :show

  def index
    @reports = Reports::Registry::REPORTS.select { |report| can_see?(report.area, report.flag) }.group_by(&:area)
    @pages = Reports::Registry::PAGES.select { |page| can_see?(page[0], page[4]) }.group_by(&:first)
  end

  def show
    @report = @report_class.new(params)
    respond_to do |format|
      format.html { load_filter_options }
      format.csv { send_data @report.to_csv, filename: csv_name }
    end
  end

  private

  def set_report
    @report_class = Reports::Registry.find(params[:id])
    raise ActiveRecord::RecordNotFound unless @report_class

    deny_access unless can_see?(@report_class.area, @report_class.flag)
  end

  def load_filter_options
    filters = @report.filters
    @customers = Customer.order(:name).pluck(:name, :id) if filters.offers?(:customer_id)
    @products = Product.order(:name).pluck(:name, :id) if filters.offers?(:product_id)
    @locations = warehouses if filters.offers?(:location_id)
    @vendors = vendors if filters.offers?(:vendor_id)
    @carriers = carriers if filters.offers?(:carrier_id)
  end

  def vendors
    Vendor.order(:name).map { |vendor| [vendor.label, vendor.id] }
  end

  # PDI carriers on orders with freight data or on fuel loads, as "1514 - Five Points Logistics".
  def carriers
    ids = carrier_ids
    names = PdiCarrier.where(pdi_carrier_id: ids).pluck(:pdi_carrier_id, :name).to_h
    ids.sort_by(&:to_i).map { |id| [[id, names[id]].compact.join(' - '), id] }
  end

  # Locations that hold stock or are PDI sites.
  def warehouses
    Location.where(id: LocationProduct.select(:location_id)).or(Location.where.not(pdi_site_code: [nil, '']))
            .order(:company_name).pluck(:company_name, :id)
  end

  def carrier_ids
    CustomerOrder.where.not(pdi_gallons: nil).where.not(pdi_carrier_id: nil).distinct.pluck(:pdi_carrier_id) |
      PdiFuelLoad.where.not(carrier_id: nil).distinct.pluck(:carrier_id)
  end

  def csv_name
    range = @report.filters.range
    "#{@report_class.key}-#{range.begin}-#{range.end}.csv"
  end
end
