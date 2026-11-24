module Planning
  # Something a planning number rests on that isn't a recorded fact: a default, an estimate or a guess. Shown as a
  # tag beside the number (shared/_assumptions) so anyone can see it and fix the data behind it
  # (Purchasing → Planning Assumptions).
  #   key    what kind (:default_lead, :default_production, :assumed_date, :vendor_guess, :cost_on_file,
  #          :short_history, :no_standard)
  #   label  the tag text; detail  the tooltip: why, and what would make it a fact
  Assumption = Struct.new(:key, :label, :detail)
end
