class ProductionOrderBatchesController < ApplicationController
  before_action :set_batch

  def update_qc
    if @batch.update(batch_qc_params)
      redirect_to @batch.production_order,
                  notice: "Batch #{@batch.batch_number} QC status updated to #{@batch.qc_status}."
    else
      redirect_to @batch.production_order,
                  alert: @batch.errors.full_messages.join(', ')
    end
  end

  def complete
    if @batch.complete_and_deduct_inventory!(current_user)
      redirect_to @batch.production_order,
                  notice: "Batch #{@batch.batch_number} completed. Raw materials deducted and finished goods added to inventory."
    else
      redirect_to @batch.production_order,
                  alert: "Cannot complete batch — QC status must be 'passed' first."
    end
  end

  private

  def set_batch
    @batch = ProductionOrderBatch.find(params[:id])
  end

  def batch_qc_params
    params.permit(:qc_status, :qc_notes, :qc_by)
  end
end
