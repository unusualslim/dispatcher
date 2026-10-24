class CostingSettingsController < ApplicationController
  before_action :require_admin!

  def edit
    @labor_rate = AppSetting.labor_rate
    @gl_accounts = ProductionOrderJournal::ACCOUNT_ROLES.keys.index_with { |r| ProductionOrderJournal.account_for(r) }
  end

  def update
    load_submitted_settings
    if (error = validation_error(@labor_rate, @gl_accounts))
      flash.now[:alert] = error
      return render :edit, status: :unprocessable_entity
    end

    AppSetting.set('labor_rate', @labor_rate)
    @gl_accounts.each { |role, account| AppSetting.set("gl_account.#{role}", account) }
    redirect_to edit_costing_settings_path, notice: t('.updated')
  end

  private

  def load_submitted_settings
    @labor_rate = params[:labor_rate].to_s.strip
    @gl_accounts = ProductionOrderJournal::ACCOUNT_ROLES.keys.index_with { |r| params.dig(:gl_accounts, r).to_s.strip }
  end

  def validation_error(rate, accounts)
    return t('.invalid_rate') unless rate.match?(/\A\d+(\.\d{1,4})?\z/) && rate.to_d.positive?

    bad = accounts.reject { |_, a| a.blank? || a.match?(ReportingGroup::ACCOUNT_FORMAT) }.keys
    t('.invalid_accounts', roles: bad.map { |r| ProductionOrderJournal::ACCOUNT_ROLES[r] }.join(', ')) if bad.any?
  end
end
