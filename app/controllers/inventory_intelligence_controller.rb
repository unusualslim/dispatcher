class InventoryIntelligenceController < ApplicationController
  before_action :require_admin!

  def show
    @report = InventoryIntelligenceService.new(report_type: :daily).run
  end

  def send_test
    report_type = params[:report_type]&.to_sym || :daily
    report = InventoryIntelligenceService.new(report_type: report_type).run

    case report_type
    when :daily
      InventoryIntelligenceMailer.daily_report(current_user, report).deliver_now
    when :weekly
      InventoryIntelligenceMailer.weekly_report(current_user, report).deliver_now
    end

    redirect_to inventory_intelligence_path, notice: "#{report_type.to_s.titleize} report sent to #{current_user.email}."
  end

  def send_all
    report_type = params[:report_type]&.to_sym || :daily
    InventoryIntelligenceJob.perform_later(report_type.to_s)
    redirect_to inventory_intelligence_path, notice: "#{report_type.to_s.titleize} report queued for all opted-in recipients."
  end
end
