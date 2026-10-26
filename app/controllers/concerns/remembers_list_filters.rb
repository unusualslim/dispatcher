# Index pages that keep each user's last filters and sort (users.list_filters[page]).
# A bare visit restores them; the filter form always sends filtered=1, and Clear sends reset=1.
module RemembersListFilters
  extend ActiveSupport::Concern

  private

  # Call first in the index action: `return if restore_list_filters('products', KEYS)`.
  # True when it redirected to the saved filters.
  def restore_list_filters(page, keys)
    given = request.query_parameters.slice(*keys, 'filtered').compact_blank
    if params[:reset].present? || given.any?
      save_list_filters(page, given.presence) # Clear (reset=1) sends no filters: forget them
      return false
    end

    redirect_to_saved_list_filters(page)
  end

  def redirect_to_saved_list_filters(page)
    saved = current_user.list_filters[page]
    redirect_to "#{request.path}?#{saved.to_query}" if saved.present?
    saved.present?
  end

  def save_list_filters(page, filters)
    return if current_user.list_filters[page] == filters

    current_user.update!(list_filters: current_user.list_filters.merge(page => filters).compact)
  end
end
