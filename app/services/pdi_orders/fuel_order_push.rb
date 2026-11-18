module PdiOrders
  # Send to PDI: an order entered in the app goes to PDI as a fuel order (PDIFuelOrders.xsd, AddFuelOrder), once.
  # Only the main information is sent: customer and ship-to (PDI IDs), delivery date and time, the customer's PO
  # number, the carrier, our order number as AlternateReferenceNo, and each line's product and gallons. Prices go as
  # 0 "not overridden" and PDI then recalculates the order (RecalculateOrder), so PDI prices it, adds freight and taxes.
  # Tanks, driver, truck and load details are filled in PDI later; the 15-minute order sync brings them back, and
  # finds this order by its PDI order number or by our reference (OrderWriter).
  class FuelOrderPush
    TARGET_STATUS = 1 # PDI "Open Order"
    REFERENCE_PREFIX = 'APP'.freeze
    GUID = /\h{8}-\h{4}-\h{4}-\h{4}-\h{12}/

    attr_reader :order

    def self.reference(order) = "#{REFERENCE_PREFIX}#{order.id}"

    # The app order a PDI order came from, by its AlternateReferenceNo ("APP123"), if it hasn't been linked yet.
    def self.order_for_reference(reference)
      id = reference.to_s[/\A#{REFERENCE_PREFIX}(\d+)\z/o, 1]
      CustomerOrder.find_by(id: id, external_order_no: nil) if id
    end

    def initialize(order)
      @order = order
    end

    # What has to be filled in before the order can go (empty = ready).
    def problems
      return ['Already sent to PDI'] if order.external_order_no.present? || order.pdi_push_status.in?(%w[queued sent])

      [customer_problem, ship_to_problem, date_problem, po_problem, *line_problems].compact
    end

    def ready? = problems.empty?

    def ship_to_id
      return unless order.customer && order.location

      CustomerLocation.find_by(customer_id: order.customer_id, location_id: order.location_id)&.pdi_location_id
    end

    def lines
      order.customer_order_products.reject(&:marked_for_destruction?).sort_by(&:id)
    end

    def xml
      FuelOrderXml.new(order, lines: lines, ship_to_id: ship_to_id, reference: self.class.reference(order)).to_xml
    end

    # Sends the order. Records PDI's reply, its order number when the reply has one (else its request ID, to be
    # checked with #check!), then asks PDI to price it. Raises PdiWebService errors after recording them.
    def push!(user:, service: PdiWebService.new)
      raise ArgumentError, problems.to_sentence unless ready?

      reply = service.add_fuel_order(xml, target_status: TARGET_STATUS)
      record_reply(reply, user)
      recalculate(service)
      order
    rescue *PdiWebService::FAILURES => e
      order.update_columns(pdi_push_status: 'failed', pdi_push_error: e.message, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
      raise
    end

    # A queued push: asks PDI for the answer to its request and links the order number when it has one.
    def check!(service: PdiWebService.new)
      return order unless queued?

      reply = service.responses(order.pdi_request_id)
      order.update!(pdi_push_response: reply.to_s.truncate(20_000))
      order_number(reply)&.then { |order_no| link!(order_no) }
      recalculate(service)
      order
    end

    def queued? = order.pdi_push_status == 'queued' && order.pdi_request_id.present?

    private

    def customer_problem
      return 'Choose the customer' unless order.customer
      return if order.customer.pdi_customer_id.present?

      "#{order.customer.name} isn't linked to a PDI customer (merge it into its PDI twin, Admin → Merge Customers)"
    end

    def ship_to_problem
      return 'Choose the delivery location' unless order.location
      return if ship_to_id.present?

      "#{order.location.company_name} isn't linked to one of the customer's PDI ship-tos"
    end

    def date_problem
      'Enter the delivery date' if order.required_delivery_date.blank?
    end

    def po_problem
      'This customer requires a PO number' if order.customer&.po_required? && order.customer_po_number.blank?
    end

    def line_problems
      return ['Add a product and gallons'] if lines.none? { |line| line.quantity.to_d.positive? }

      lines.filter_map do |line|
        next 'A line has no product' unless line.product
        next "#{line.product_id} isn't a fuel product (only fuel orders can be sent)" unless fuel?(line.product)

        "#{line.product_id} needs gallons" unless line.quantity.to_d.positive?
      end
    end

    def fuel?(product)
      product.reporting_group&.item_type == 'fuel'
    end

    def record_reply(reply, user)
      order_no = order_number(reply)
      order.update!(pdi_push_status: order_no ? 'sent' : 'queued', pdi_pushed_at: Time.current,
                    pdi_pushed_by_id: user&.id, pdi_request_id: reply.to_s[GUID], pdi_push_error: nil,
                    pdi_push_response: reply.to_s.truncate(20_000), order_status: :open_order)
      link!(order_no) if order_no
    end

    # The order number in PDI's reply, if it carries one.
    def order_number(reply)
      doc = Nokogiri::XML(reply.to_s).tap(&:remove_namespaces!)
      doc.at('OrderNo')&.text.presence
    end

    # Takes PDI's order number unless another app order already has it (then the sync sorts it out).
    def link!(order_no)
      return if CustomerOrder.where(external_order_no: order_no).where.not(id: order.id).exists?

      order.update!(external_order_no: order_no, pdi_push_status: 'sent')
    end

    def recalculate(service)
      return if order.external_order_no.blank?

      service.recalculate_order(order.external_order_no)
    rescue *PdiWebService::FAILURES => e
      order.update_columns(pdi_push_error: "Sent, but PDI didn't re-price it: #{e.message}") # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
