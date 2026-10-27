module Reports
  # Every report, plus the existing pages that work as reports, grouped by area for the Reports hub.
  # Add new reports here.
  module Registry
    AREAS = { 'sales' => 'Sales & delivery', 'production' => 'Production & quality', 'inventory' => 'Inventory',
              'purchasing' => 'Purchasing', 'accounting' => 'Accounting' }.freeze

    REPORTS = [
      SalesByCustomer, SalesByProduct, SalesByMonth, DeliveryByCustomer, LateOrders, PricingExceptions,
      QualityResults, InventoryMovements, PoSpendByVendor, PpvByProduct
    ].freeze

    # Existing pages, listed alongside: [area, title, description, route helper].
    PAGES = [
      ['sales', 'Open pricing exceptions', 'Unbilled order lines priced off the lock or rule (re-check, review).',
       :price_exceptions_path],
      ['sales', 'Quote margin review', 'Locked quote prices against today\'s cost; what needs re-pricing.',
       :quote_margin_review_path],
      ['production', 'Quality exceptions', 'Out-of-range results waiting for review.', :quality_exceptions_path],
      ['production', 'BOM cost report', 'Standard cost of each product\'s bill of materials.',
       :bom_cost_report_production_orders_path],
      ['inventory', 'Inventory valuation', 'Stock value by category, product and location as of any date.',
       :inventory_valuation_path],
      ['inventory', 'Inventory history', 'Every inventory transaction, with running balance.',
       :inventory_transactions_path],
      ['inventory', 'Inventory insights', 'Stock-outs, reorder alerts and the daily inventory email.',
       :inventory_intelligence_path],
      ['purchasing', 'Purchasing report', 'What to order and from which vendor.', :purchasing_report_path],
      ['purchasing', 'MRP', 'When each item runs out per warehouse, and why.', :mrp_path],
      ['accounting', 'Financial dashboard', 'Month to date vs prior month and last year.', :financial_dashboard_path],
      ['accounting', 'GL ledger', 'Posted FPST journal entries and exports.', :ledger_entries_path]
    ].freeze

    def self.find(key)
      REPORTS.find { |report| report.key == key.to_s }
    end
  end
end
