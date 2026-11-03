class ThingsController < ApplicationController
  before_action :require_admin!
  before_action :set_thing, only: %i[show edit update destroy]

  def index
    @category = params[:category].presence_in(Thing::CATEGORIES.keys)
    @counts = Thing.group(:category).count
    @things = Thing.includes(:location).order(:category, :name)
    @things = @things.where(category: @category) if @category
  end

  def show; end

  def new
    @thing = Thing.new(category: params.dig(:thing, :category).presence_in(Thing::CATEGORIES.keys) || 'truck')
  end

  def destroy
    if @thing.destroy
      redirect_to things_path, notice: "#{@thing.name} was deleted."
    else
      redirect_to @thing, alert: "#{@thing.name} can't be deleted: #{@thing.errors.full_messages.to_sentence}"
    end
  end

  def edit; end

  def update
    if @thing.update(thing_params)
      redirect_to @thing, notice: 'Thing was successfully updated.'
    else
      render :edit, status: :unprocessable_content
    end
  end

  def create
    @thing = Thing.new(thing_params)
    if @thing.save
      redirect_to @thing, notice: 'Thing was successfully created.'
    else
      render :new, status: :unprocessable_content
    end
  end

  def search
    @things = Thing.where('name ILIKE ?', "%#{params[:query]}%")
    render json: @things.map { |thing| { id: thing.id, name: thing.name } }
  end

  private

  def set_thing
    @thing = Thing.find(params[:id])
  end

  def thing_params
    params.require(:thing).permit(:name, :category, :location_id, :serial_number, :production_line, :install_status,
                                  :power, :purchased_from, :invoice_number, :year_made)
  end
end
