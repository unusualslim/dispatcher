module PdiMasterData
  # PDI customers → customers.pdi_customer_id. The first run links existing customers by name;
  # PDI's name and phone win after that. Inactive PDI customers aren't added.
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
      return update(id, @linked[id], attrs) if @linked[id]

      match = @unlinked[normalize(attrs[:name])]&.shift
      return update(id, match, attrs.merge(pdi_customer_id: id), :link) if match
      return record(:skip, id, attrs[:name], {}, 'Inactive in PDI') unless active?(node)

      create(id, attrs)
    end

    def customer_attrs(node)
      { name: text(node, 'Description'), phone: text(node, 'Phone') }.compact
    end

    def active?(node)
      text(node, 'AccountStatus') == 'Active'
    end

    def update(id, customer, attrs, action = :update)
      changes = diff(customer, attrs)
      customer.update!(changes) if apply? && changes.any?
      customers[id] = customer
      record(action == :update && changes.empty? ? :unchanged : action, id, attrs[:name], changes)
    end

    def create(id, attrs)
      customer = Customer.create!(attrs.merge(pdi_customer_id: id, preferred_contact_method: 'no preference')) if apply?
      customers[id] = customer
      record(:create, id, attrs[:name], attrs)
    end
  end
end
