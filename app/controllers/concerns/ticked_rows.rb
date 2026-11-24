# Suggestion pages post their rows as rows[i][field] with rows[i][pick] = '1' on the ticked ones.
module TickedRows
  extend ActiveSupport::Concern

  private

  # The ticked rows under params[key], each as a hash of the given fields.
  def ticked(key, fields)
    params.fetch(key, {}).values.select { |row| row[:pick] == '1' }
          .map { |row| row.permit(*fields).to_h.symbolize_keys }
  end
end
