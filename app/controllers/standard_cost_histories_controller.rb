class StandardCostHistoriesController < ApplicationController
  before_action :require_admin!

  def create
    @product = Product.find(params[:product_id])
    history = @product.standard_cost_histories.build(
      amount:         params[:standard_cost_history][:amount],
      effective_date: params[:standard_cost_history][:effective_date],
      created_by:     current_user
    )

    if history.save
      # Keep the column in sync with the cost in effect today, not just the last entry
      # (a back-dated or future-dated entry shouldn't overwrite the current cost).
      @product.standard_cost_histories.reset
      @product.update_column(:standard_cost, @product.current_standard_cost)
      redirect_to product_path(@product), notice: "Standard cost updated to $#{"%.4f" % history.amount} (effective #{history.effective_date.strftime("%B %-d, %Y")})."
    else
      redirect_to product_path(@product), alert: history.errors.full_messages.to_sentence
    end
  end
end
