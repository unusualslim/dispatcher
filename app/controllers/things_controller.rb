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

  def create
    @thing = Thing.new(thing_params)
    if @thing.save
      redirect_to @thing, notice: 'Thing was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_thing
    @thing = Thing.find(params[:id])
  end

  def thing_params
    params.require(:thing).permit(:name)
  end
end