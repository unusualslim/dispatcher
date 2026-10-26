module PdiOrders
  # PDI site ID (2, 110, 7777…) → the app location with that pdi_site_code ("0002", "0110"); nil for
  # dropship or unknown sites.
  module Warehouses
    MAIN_SITE = '0002'.freeze # Five Points Service / FPS-Main

    def self.for_site(site)
      return if site.blank?

      Location.find_by(pdi_site_code: [site, site.to_s.rjust(4, '0')])
    end

    # A fuel line not yet on a load has no origin site: plan it at the main warehouse until it's loaded.
    def self.for_line(line)
      return for_site(line.site) if line.site.present?

      Location.find_by(pdi_site_code: MAIN_SITE) if line.fuel
    end
  end
end
