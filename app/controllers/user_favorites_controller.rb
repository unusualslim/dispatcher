class UserFavoritesController < ApplicationController
  before_action :authenticate_user!

  def create
    label = params[:label].to_s.strip
    path  = params[:path].to_s.strip

    return head :bad_request if label.blank? || path.blank?

    max_pos = current_user.user_favorites.maximum(:position) || 0
    fav = current_user.user_favorites.find_or_initialize_by(path: path)
    fav.label    = label
    fav.position = fav.new_record? ? max_pos + 1 : fav.position
    fav.save!

    render json: { id: fav.id, label: fav.label, path: fav.path }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    fav = current_user.user_favorites.find(params[:id])
    fav.destroy
    head :no_content
  end

  def reorder
    ids = params[:ids].to_a
    ids.each_with_index do |id, idx|
      current_user.user_favorites.where(id: id).update_all(position: idx + 1)
    end
    head :no_content
  end
end
