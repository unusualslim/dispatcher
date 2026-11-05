# Admin → Company Info: the name, address and contact details printed on customer-facing documents
# (quotes for now).
class CompanySettingsController < ApplicationController
  before_action :require_admin!

  def edit
    @company = AppSetting.company
  end

  def update
    @company = submitted_company
    if @company['name'].blank?
      flash.now[:alert] = t('.name_required')
      return render :edit, status: :unprocessable_content
    end

    @company.each { |key, value| AppSetting.set("company.#{key}", value) }
    redirect_to edit_company_settings_path, notice: t('.updated')
  end

  private

  def submitted_company
    AppSetting::COMPANY_KEYS.index_with { |key| params.dig(:company, key).to_s.strip }
  end
end
