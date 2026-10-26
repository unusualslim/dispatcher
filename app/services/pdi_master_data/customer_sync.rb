module PdiMasterData
  # PDI customers → customers.pdi_customer_id. The first run links existing customers by name;
  # PDI's name, phone and active flag win after that. A customer inactive in PDI is only marked
  # inactive (and linked), never added, and its ship-tos are left alone.
  class CustomerSync < Sync
    SECTION = :customers

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
      return update(id, customer, changes(node, attrs, id, action), attrs[:name], action) if customer
      return record(:skip, id, attrs[:name], {}, 'Inactive in PDI') unless active?(node)

      create(id, attrs)
    end

    # [customer, :update] when already linked, [customer, :link] for an unlinked one with the same name.
    def existing(id, name)
      return [@linked[id], :update] if @linked[id]

      match = @unlinked[normalize(name)]&.shift
      [match, :link] if match
    end

    def customer_attrs(node)
      { name: text(node, 'Description'), phone: text(node, 'Phone') }.compact
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
