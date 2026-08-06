class JobsController < ApplicationController
  before_action :require_admin_or_line_lead!
  before_action :set_job, only: [:clock_out]

  def line
    @line_workers = User.line_workers.order(:first_name, :last_name)
    @production_orders = ProductionOrder.where(status: %w[pending in_progress]).order(:number)
    @job_types = Job::JOB_TYPES
    @active_job = Job.active.order(started_at: :desc).first
  end

  def create
    worker_ids = params[:worker_ids].presence || []
    if worker_ids.empty?
      return redirect_to line_path, alert: "Select at least one worker before clocking in."
    end

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

    redirect_to line_path, notice: "Clocked in — timer running."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to line_path, alert: "Could not clock in: #{e.message}"
  end

  def clock_out
    @job.clock_out!
    redirect_to line_path, notice: "Clocked out. Job duration: #{@job.duration_formatted}."
  rescue => e
    redirect_to line_path, alert: "Clock out failed: #{e.message}"
  end

  private

  def set_job
    @job = Job.find(params[:id])
  end

  def require_admin_or_line_lead!
    unless admin? || current_user.role == 'line_worker'
      redirect_to dispatches_path, alert: "Access denied."
    end
  end
end
