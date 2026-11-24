module PdiMasterData
  # A PDI customer's <Contact>s → its customer_contacts (source pdi). PDI contacts carry no ID, so a contact is
  # matched by email, else by name; matched contacts take PDI's details and keep the app's invoice_recipient tick.
  # PDI contacts no longer in the feed are marked inactive (never deleted). Contacts added in the app are untouched.
  class ContactSync
    def initialize(customer, node)
      @customer = customer
      @node = node
    end

    def call
      return unless @customer

      existing = @customer.customer_contacts.where(source: 'pdi').index_by(&:match_key)
      seen = contact_attrs.map { |attrs| save_contact(existing, attrs) }
      existing.except(*seen).each_value { |contact| contact.update!(active: false) if contact.active }
    end

    private

    def contact_attrs
      @node.xpath('Contact').map { |node| attrs_from(node) }
           .select { |attrs| attrs.values_at(:first_name, :last_name, :email).any? }.uniq { |attrs| key(attrs) }
    end

    def attrs_from(node)
      { first_name: text(node, 'FirstName'), last_name: text(node, 'LastName'), email: text(node, 'Email'),
        phone: text(node, 'Phone'), active: %w[0 no false].exclude?(text(node, 'Active').to_s.downcase) }
    end

    def save_contact(existing, attrs)
      contact = existing[key(attrs)] || @customer.customer_contacts.new(source: 'pdi')
      contact.assign_attributes(attrs)
      contact.save! if contact.changed?
      key(attrs)
    end

    def key(attrs) = CustomerContact.match_key(attrs[:first_name], attrs[:last_name], attrs[:email])
    def text(node, path) = node.at_xpath(path)&.text&.strip.presence
  end
end
