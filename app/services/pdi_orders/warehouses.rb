module PdiOrders
  # PDI site ID (2, 110, 7777…) → the app location with that pdi_site_code ("0002", "0110"); nil for
  # dropship or unknown sites.
  module Warehouses
    def self.for_site(site)
      return if site.blank?

      Location.find_by(pdi_site_code: [site, site.to_s.rjust(4, '0')])
    end
  end
end
