# The building blocks of access (UserPermissions, Role): areas and levels, feature rights, data flags,
# assistant levels and user types. Included in User, so they read as User::AREAS, User::FEATURES…
module AccessCatalog
  AREAS = {
    'sales' => 'Sales',
    'dispatch' => 'Dispatch',
    'production' => 'Production',
    'purchasing' => 'Purchasing',
    'inventory' => 'Inventory',
    'accounting' => 'Accounting'
  }.freeze
  LEVELS = %w[view edit approve].freeze

  # Feature rights: what someone may create or change (viewing follows the area level and data flags).
  FEATURES = {
    'quotes' => { area: 'sales', label: 'Quotes', hint: 'Create and change quotes' },
    'pricing_rules' => { area: 'sales', label: 'Pricing rules', hint: 'Change pricing rules' },
    'freight_setup' => { area: 'sales', label: 'Freight setup', hint: 'Freight rules, tables, classes and lanes' },
    'customers' => { area: 'sales', label: 'Customers & locations',
                     hint: 'Add and change customers, sites, phone numbers' },
    'inventory_pos' => { area: 'purchasing', label: 'Inventory POs',
                         hint: 'Create and change inventory purchase orders' },
    'expense_pos' => { area: 'purchasing', label: 'Expense POs', hint: 'Create and change expense purchase orders' },
    'vendors' => { area: 'purchasing', label: 'Vendors', hint: 'Add and change vendors' },
    'adjustments' => { area: 'inventory', label: 'Inventory adjustments', hint: 'Adjust stock on hand' },
    'products' => { area: 'inventory', label: 'Products & BOMs', hint: 'Change products, BOMs and standard costs' },
    'quality' => { area: 'production', label: 'Quality results', hint: 'Record and review quality checks' },
    'gl_entries' => { area: 'accounting', label: 'GL postings', hint: 'Post, reverse and export GL entries' },
    'costing_setup' => { area: 'accounting', label: 'Costing setup',
                         hint: 'Cost items, reporting groups, costing settings, expense accounts' }
  }.freeze

  # Sensitive data across areas.
  DATA_FLAGS = {
    'costs' => { label: 'Costs & margins', hint: 'Inventory value, standard and component costs, margins' },
    'customer_pricing' => { label: 'Customer pricing', hint: 'Pricing rules, quotes, price locks and exceptions' },
    'gl' => { label: 'GL & accounting entries', hint: 'Ledger, GL postings, expense accounts' },
    'financial_dashboard' => { label: 'Financial dashboard & sales totals',
                               hint: 'Financial dashboard and sales-by reports' }
  }.freeze
  # Never sent to the AI assistant, whatever a user's roles allow.
  NEVER_TO_ASSISTANT = %w[customer_pricing gl].freeze

  ASSISTANT_LEVELS = {
    'off' => 'Off',
    'ask' => 'Ask questions',
    'query' => 'Ask + ad-hoc queries'
  }.freeze

  ROLES = {
    'admin' => 'Admin',
    'staff' => 'Staff',
    'worker' => 'Driver',
    'line_worker' => 'Line Worker'
  }.freeze
end
