# The pages a user can pick as their home page (My Account, Users, or right-click a sidebar link → Set as Home
# Page). `area` is the permission area that must be viewable; nil = any staff. A user's favorites are offered too.
module HomePage
  Option = Struct.new(:label, :route, :area, keyword_init: true) do
    def path = Rails.application.routes.url_helpers.public_send(route)
  end

  OPTIONS = [
    ['Reports', :reports_path, nil],
    ['Dispatch Dashboard', :dispatches_path, 'dispatch'],
    ['Dispatch Board', :kanban_dispatches_path, 'dispatch'],
    ['Dispatch List', :view_dispatches_path, 'dispatch'],
    ['Calendar', :calendar_path, 'dispatch'],
    ['Map', :locations_map_path, 'dispatch'],
    ['Order Dashboard', :dashboard_customer_orders_path, 'sales'],
    ['Customer Orders', :customer_orders_path, 'sales'],
    ['Quotes', :quotes_path, 'sales'],
    ['Customers', :customers_path, 'sales'],
    ['Production Dashboard', :dashboard_production_orders_path, 'production'],
    ['Production Kanban', :kanban_production_orders_path, 'production'],
    ['Production Orders', :production_orders_path, 'production'],
    ['Line Production', :line_path, 'production'],
    ['Warehouse Board', :warehouse_kanban_path, 'production'],
    ['PO Dashboard', :dashboard_purchase_orders_path, 'purchasing'],
    ['Purchase Orders', :purchase_orders_path, 'purchasing'],
    ['MRP', :mrp_path, 'purchasing'],
    ['Inventory Insights', :inventory_intelligence_path, 'inventory'],
    ['Products', :products_path, 'inventory'],
    ['Financial Dashboard', :financial_dashboard_path, 'accounting'],
    ['GL Ledger', :ledger_entries_path, 'accounting']
  ].map { |label, route, area| Option.new(label: label, route: route, area: area) }.freeze

  # A path inside the app: no host, no protocol-relative "//", no whitespace.
  FORMAT = %r{\A/(?!/)\S*\z}

  # Only admins and staff choose; drivers and line workers keep their fixed screens.
  def self.choosable?(user)
    user.admin? || user.staff?
  end

  # [label, path] pairs for a picker: the pages the user can see, then their favorites, then their current
  # choice if it's neither (set from the sidebar on some other page).
  def self.choices(user)
    list = (pages_for(user) + favorites_for(user)).uniq(&:last)
    current = user.home_page
    current.nil? || list.any? { |_, path| path == current } ? list : list + [[current, current]]
  end

  def self.pages_for(user)
    OPTIONS.select { |option| option.area.nil? || user.can?(option.area) }.map { |o| [o.label, o.path] }
  end

  def self.favorites_for(user)
    user.user_favorites.order(:position).map { |fav| ["★ #{fav.label}", fav.path] }
  end
end
