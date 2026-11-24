module PdiMasterData
  # PDI customers → customers.pdi_customer_id. The first run links existing customers by name; PDI's name,
  # phone, master (bill-to) address, PO-required flag and active flag win after that, and its contacts are kept in
  # step (ContactSync). A customer inactive in PDI is only marked inactive (and linked), never added, and its
  # ship-tos and contacts are left alone.
  class CustomerSync < Sync
    SECTION = :customers
    # PDI master address field → customers column. Always sent (a blank clears it).
    BILL_TO = { 'Address1' => :bill_address1, 'Address2' => :bill_address2, 'City' => :bill_city,
                'StateProvinceID' => :bill_state, 'PostalCode' => :bill_zip, 'County' => :bill_county }.freeze

    def call
      @linked = Customer.where.not(pdi_customer_id: nil).index_by(&:pdi_customer_id)
      @unlinked = Customer.where(pdi_customer_id: nil).order(:id).group_by { |c| normalize(c.name) }
      customer_nodes.each { |node| guard(text(node, 'ID'), text(node, 'Description')) { sync(node) } }
    end

    private

    def sync(node)
      id = text(node, 'ID')
      attrs = customer_attrs(node)
      customer, action = existing(id, attrs[:name])
      return record(:skip, id, attrs[:name], {}, 'Inactive in PDI') unless customer || active?(node)

      save_customer(id, customer, attrs, node, action)
      ContactSync.new(customers[id], node).call if apply? && active?(node)
    end

    def save_customer(id, customer, attrs, node, action)
      customer ? update(id, customer, changes(node, attrs, id, action), attrs[:name], action) : create(id, attrs)
    end

    # [customer, :update] when already linked, [customer, :link] for an unlinked one with the same name.
    def existing(id, name)
      return [@linked[id], :update] if @linked[id]

      match = @unlinked[normalize(name)]&.shift
      [match, :link] if match
    end

    def customer_attrs(node)
      bill_to = BILL_TO.to_h { |tag, column| [column, text(node, tag)] }
      attrs = { name: text(node, 'Description'), phone: text(node, 'Phone'), po_required: po_required(node) }
      attrs.compact.merge(bill_to)
    end

    # PDI keeps "PO number required" per sales type (Bulk Fuel, Warehouse Products, Non Inventory Sales); the app has
    # one flag, on when any type requires a PO. nil (left alone) when PDI sends none.
    def po_required(node)
      flags = node.xpath('SalesInformation/PONumberRequired').map { |flag| flag.text.strip }
      flags.include?('Yes') if flags.any?
    end

    # An inactive customer only has its flag changed (and its PDI ID set when linking).
    def changes(node, attrs, id, action)
      changes = active?(node) ? attrs.merge(active: true) : { active: false }
      action == :link ? changes.merge(pdi_customer_id: id) : changes
    end

    def active?(node)
      text(node, 'AccountStatus') == 'Active'
    end

    # Only active customers go on to the ship-to sync.
    def update(id, customer, attrs, name, action)
      changes = diff(customer, attrs)
      customer.update!(changes) if apply? && changes.any?
      customers[id] = customer unless attrs[:active] == false
      record(action == :update && changes.empty? ? :unchanged : action, id, name, changes,
             attrs[:active] == false ? 'Inactive in PDI' : nil)
    end

    def create(id, attrs)
      customer = Customer.create!(attrs.merge(pdi_customer_id: id, preferred_contact_method: 'no preference')) if apply?
      customers[id] = customer
      record(:create, id, attrs[:name], attrs)
    end
  end
end
