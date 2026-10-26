module Mrp
  # One dated change to a product's projected stock: +supply / -demand.
  #   kind: :purchase (open PO line), :production (open production order output), :order (customer
  #         order line), :component (open production order component), :planned_production /
  #         :planned_purchase (MRP's suggestions), :planned_component (feeds a planned production)
  #   flags: :late (PO past its date), :overdue (customer order past its delivery date), :draft (draft PO)
  #   original_date: the PO's / order's own date when it was before today (date is then today)
  Event = Struct.new(:date, :qty, :kind, :label, :path, :flags, :original_date, keyword_init: true) do
    def supply? = qty.positive?
    def planned? = kind.to_s.start_with?('planned')
  end
end
