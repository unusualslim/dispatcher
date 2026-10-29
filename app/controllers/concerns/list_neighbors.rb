# Previous / Next on show pages: the records either side of this one, in the order its list shows them.
module ListNeighbors
  extend ActiveSupport::Concern

  private

  # ids: the list's ids in order. When the record isn't in it (filtered out, or opened from elsewhere),
  # `fallback` supplies the ids to use instead.
  def find_list_neighbors(record, ids, fallback: nil)
    ids = fallback.call if fallback && ids.exclude?(record.id)
    index = ids.index(record.id)
    @previous_id = index&.positive? ? ids[index - 1] : nil
    @next_id = index ? ids[index + 1] : nil
  end

  # The user's remembered filters and sort for a list page (RemembersListFilters), as query params.
  def remembered_list_params(page)
    (current_user.list_filters[page] || {}).with_indifferent_access
  end
end
