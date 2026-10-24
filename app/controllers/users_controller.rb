class UsersController < ApplicationController
  before_action :require_admin!
  before_action :set_user, only: %i[show edit update destroy deactivate reactivate]

  # GET /users or /users.json
  def index
    @users = User.all
    @user = User.new
  end

  # GET /users/1 or /users/1.json
  def show
    @user = User.find(params[:id])

    @start_date = params[:start_date].present? ? (Date.parse(params[:start_date]) rescue nil) : nil
    @end_date   = params[:end_date].present?   ? (Date.parse(params[:end_date])   rescue nil) : nil

    dispatches = @user.dispatches.where.not(status: 'deleted').order(dispatch_date: :desc)
    dispatches = dispatches.where('dispatch_date >= ?', @start_date) if @start_date
    dispatches = dispatches.where('dispatch_date <= ?', @end_date)   if @end_date
    @dispatches = dispatches.includes(customer_orders: %i[location customer_order_products])

    job_workers = @user.job_workers.includes(job: :production_order).order(clocked_in_at: :desc)
    job_workers = job_workers.where('clocked_in_at >= ?', @start_date.to_time.beginning_of_day) if @start_date
    job_workers = job_workers.where('clocked_in_at <= ?', @end_date.to_time.end_of_day) if @end_date
    @job_workers = job_workers
  end

  # GET /users/new
  def new
    @user = User.new
  end

  # GET /users/1/edit
  def edit; end

  # POST /users or /users.json
  def create
    super do |user|
      Rails.logger.debug { "User creation failed: #{user.errors.full_messages.join(', ')}" } if user.errors.any?
    end
  end

  # POST /users/line_worker — quick-add a display-only line worker (no login needed)
  def create_line_worker
    first = params[:first_name].to_s.strip
    last  = params[:last_name].to_s.strip

    return redirect_to users_path, alert: 'First and last name are required.' if first.blank? || last.blank?

    placeholder_email = "#{first.downcase}.#{last.downcase}.#{SecureRandom.hex(4)}@nologin.internal"
    user = User.new(
      first_name: first,
      last_name: last,
      email: placeholder_email,
      password: SecureRandom.hex(16),
      role: 'line_worker',
      employment_type: params[:employment_type].presence || 'full_time'
    )

    if user.save
      redirect_to users_path, notice: "#{user.full_name} added as a line worker."
    else
      redirect_to users_path, alert: "Could not add worker: #{user.errors.full_messages.join(', ')}"
    end
  end

  # PATCH/PUT /users/1 or /users/1.json
  def update
    respond_to do |format|
      if @user.update(user_params)
        format.html { redirect_to users_url, notice: 'User updated.' }
        format.json { render :show, status: :ok, location: @user }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  # Inactive users keep their history but can't sign in and leave the pickers.
  def deactivate
    return redirect_to users_url, alert: t('.self') if @user == current_user

    @user.update!(deactivated_at: Time.current)
    redirect_to users_url, notice: t('.deactivated', name: display_name(@user))
  end

  def reactivate
    @user.update!(deactivated_at: nil)
    redirect_to users_url, notice: t('.reactivated', name: display_name(@user))
  end

  # DELETE /users/1 or /users/1.json
  def destroy
    reasons = @user.history_reasons
    if reasons.any?
      return redirect_to users_url, alert: t('.has_history', name: display_name(@user), reasons: reasons.to_sentence)
    end

    @user.destroy!

    respond_to do |format|
      format.html { redirect_to users_url, notice: 'User was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private

  def display_name(user)
    user.full_name.strip.presence || user.email
  end

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    permitted = params.require(:user).permit(
      :email, :first_name, :last_name, :phone_number, :role, :employment_type,
      :sms_opt_in, :email_opt_in, :password, :password_confirmation, permissions: User::AREAS.keys
    )
    # Don't touch the password if the field was left blank
    if permitted[:password].blank?
      permitted.delete(:password)
      permitted.delete(:password_confirmation)
    end
    permitted
  end
end
