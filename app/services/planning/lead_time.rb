module Planning
  # Where a lead time comes from, so planners can see which dates rest on the app-wide defaults (MRP page):
  #   purchase   product.lead_time_days → its primary vendor's → mrp_purchase_lead_days (default)
  #   production product.production_days → mrp_production_days (default)
  class LeadTime
    attr_reader :days, :source

    def initialize(days, source)
      @days = days
      @source = source
    end

    def default? = source == :default

    def self.purchase(product)
      return new(product.lead_time_days, :product) if product.lead_time_days
      return new(product.primary_vendor.lead_time_days, :vendor) if product.primary_vendor&.lead_time_days

      new(AppSetting.mrp_days('mrp_purchase_lead_days'), :default)
    end

    def self.production(product)
      return new(product.production_days, :product) if product.production_days

      new(AppSetting.mrp_days('mrp_production_days'), :default)
    end

    def self.for(product, made:) = made ? production(product) : purchase(product)

    # The assumption to show when the default was used, else nil.
    def assumption(made:)
      return unless default?

      if made
        Assumption.new(:default_production, "Default #{days}-day production time", 'No production days on the product.')
      else
        Assumption.new(:default_lead, "Default #{days}-day lead time", 'No lead time on the product or its vendor.')
      end
    end
  end
end
