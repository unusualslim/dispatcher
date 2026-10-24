class JobsController < ApplicationController
  before_action :require_admin_or_line_lead!
  before_action :require_admin!, only: :update
  before_action :set_job, only: %i[show update clock_out]

  def line
    @line_workers = User.line_workers.order(:first_name, :last_name)
    @production_orders = ProductionOrder.where(status: ProductionOrder::OPEN_STATUSES).order(:number)
    @job_types = Job::JOB_TYPES
    @active_job = Job.active.order(started_at: :desc).first
  end

  def create
    worker_ids = params[:worker_ids].presence || []
    return redirect_to line_path, alert: 'Select at least one worker before clocking in.' if worker_ids.empty?

    production_order = ProductionOrder.find(params[:production_order_id])
    now = Time.current

    @job = Job.new(
      production_order: production_order,
      created_by: current_user,
      job_type: params[:job_type],
      started_at: now
    )

    Job.transaction do
      @job.save!
      worker_ids.each do |uid|
        @job.job_workers.create!(user_id: uid, clocked_in_at: now)
      end
    end

    redirect_to line_path, notice: 'Clocked in — timer running.'
  rescue ActiveRecord::RecordInvalid => e
    redirect_to line_path, alert: "Could not clock in: #{e.message}"
  end

  def show; end

  # Admin correction of a finished job's clock times.
  def update
    return redirect_to @job, alert: t('.still_running') if @job.active?

    @job.correct_times!(worker_times_params, current_user)
    notice = t('.updated')
    notice += " #{t('.posted_entry')}" if LedgerEntry.active_for(@job.production_order)
    redirect_to @job, notice: notice
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @job, alert: t('.invalid', error: e.record.errors.full_messages.to_sentence)
  end

  def clock_out
    @job.clock_out!
    redirect_to line_path, notice: "Clocked out. Job duration: #{@job.duration_formatted}."
  rescue StandardError => e
    redirect_to line_path, alert: "Clock out failed: #{e.message}"
  end

  private

  def worker_times_params
    params.require(:job_workers)
          .permit(@job.job_worker_ids.map { |id| { id.to_s => %i[clocked_in_at clocked_out_at] } }).to_h
  end

  def set_job
    @job = Job.find(params[:id])
  end

  def require_admin_or_line_lead!
    redirect_to dispatches_path, alert: 'Access denied.' unless admin? || current_user.role == 'line_worker'
  end
end
