class ThingsController < ApplicationController
  before_action :set_thing, only: [:show, :edit, :update, :destroy]

  def index
    @things = Thing.all
  end

  def show
  end

  def new
    @thing = Thing.new
  end

  def destroy
    @thing.destroy
    respond_to do |format|
      format.html { redirect_to things_path, notice: 'Thing was successfully deleted.' }
      format.json { head :no_content }
    end
  end

  def edit
  end

  def update
    if @thing.update(thing_params)
      redirect_to @thing, notice: 'Thing was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def create
    @thing = Thing.new(thing_params)
    if @thing.save
      redirect_to @thing, notice: 'Thing was successfully created.'
    else
      render :new, status: :unprocessable_entity
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
    params.require(:thing).permit(:name, :category)
  end
end