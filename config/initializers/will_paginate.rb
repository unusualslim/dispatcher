require 'will_paginate/view_helpers/action_view'

class BootstrapPaginationRenderer < WillPaginate::ActionView::LinkRenderer
  def container_tag
    :ul
  end

  def container_attributes
    { class: 'pagination pagination-sm mb-0' }
  end

  def page_number(page)
    if page == current_page
      tag(:li, tag(:a, page, class: 'page-link', href: '#'), class: 'page-item active')
    else
      tag(:li, link(page, page, class: 'page-link'), class: 'page-item')
    end
  end

  def previous_page
    num = @collection.current_page > 1 && @collection.current_page - 1
    previous_or_next_page(num, '&lsaquo;', 'previous')
  end

  def next_page
    num = @collection.current_page < total_pages && @collection.current_page + 1
    previous_or_next_page(num, '&rsaquo;', 'next')
  end

  def gap
    tag(:li, tag(:span, '&hellip;', class: 'page-link'), class: 'page-item disabled')
  end

  private

  def previous_or_next_page(page, text, classname)
    if page
      tag(:li, link(text.html_safe, page, class: 'page-link'), class: "page-item #{classname}")
    else
      tag(:li, tag(:a, text.html_safe, class: 'page-link'), class: "page-item #{classname} disabled")
    end
  end
end
