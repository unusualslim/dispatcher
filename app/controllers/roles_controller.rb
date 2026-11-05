# Admin → Roles: custom roles (area levels, feature rights, data flags, assistant level) that admins give to
# staff users on the Users page. A user can hold several; access adds up.
class RolesController < ApplicationController
  before_action :require_admin!
  before_action :set_role, only: %i[edit update destroy]

  def index
    @roles = Role.ordered.includes(:users)
  end

  def new
    @role = Role.new
  end

  def edit; end

  def create
    @role = Role.new(role_params)
    if @role.save
      redirect_to roles_path, notice: t('.created', name: @role.name)
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @role.update(role_params)
      redirect_to roles_path, notice: t('.updated', name: @role.name)
    else
      render :edit, status: :unprocessable_content
    end
  end

  # Holders simply lose what this role gave them.
  def destroy
    @role.destroy!
    redirect_to roles_path, notice: t('.deleted', name: @role.name)
  end

  private

  def set_role
    @role = Role.find(params[:id])
  end

  def role_params
    params.expect(role: [:name, :description, :assistant_level,
                         { area_levels: User::AREAS.keys, features: [], data_flags: [] }])
  end
end
