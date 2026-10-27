module ProductsHelper
  # Active cost items for a cost line's picker, plus the line's own item if it has been retired.
  def cost_item_options(selected_id)
    CostItem.where(active: true).or(CostItem.where(id: selected_id)).ordered.map { |item| [item.label, item.id] }
  end
end
