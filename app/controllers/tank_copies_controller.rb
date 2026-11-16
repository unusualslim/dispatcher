# Dispatch → Tanks → Copy from location settings: previews and creates tanks from the old tank fields on location
# products (TankCopy). Admin only: it creates many records at once.
class TankCopiesController < ApplicationController
  before_action :require_admin!

  def new
    @copy = TankCopy.new
  end

  def create
    tanks = TankCopy.new.run!
    redirect_to tanks_path, notice: t('.copied', count: tanks.size)
  end
end
