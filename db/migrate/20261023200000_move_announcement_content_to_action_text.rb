class MoveAnnouncementContentToActionText < ActiveRecord::Migration[7.2]
  # The announcement form always used the rich-text editor, but the model never declared
  # has_rich_text, so the editor's HTML landed in this plain column and showed as raw markup.
  # Older rows are plain text. Copy both into Action Text, then drop the column.
  def up
    select_rows('SELECT id, content FROM announcements WHERE content IS NOT NULL').each do |id, content|
      body = content.match?(/<[a-z][^>]*>/i) ? content : ERB::Util.html_escape(content).gsub(/\r?\n/, '<br>')
      ActionText::RichText.create!(record_type: 'Announcement', record_id: id, name: 'content', body: body)
    end
    remove_column :announcements, :content
  end

  def down
    add_column :announcements, :content, :text
    ActionText::RichText.where(record_type: 'Announcement', name: 'content').find_each do |rich_text|
      execute "UPDATE announcements SET content = #{quote(rich_text.body.to_html)} " \
              "WHERE id = #{rich_text.record_id.to_i}"
      rich_text.destroy!
    end
  end
end
