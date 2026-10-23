require 'csv'

# Adds bulk CSV export + import to any admin controller.
#
# Including controller must define:
#   def csv_resource  — the ActiveRecord class (e.g. Product)
#   def csv_columns   — array of { attr:, header:, readonly: } hashes
#
module CsvRoundTrip
  extend ActiveSupport::Concern

  # GET /resources/export_csv?ids[]=1&ids[]=2
  def export_csv
    ids   = Array(params[:ids]).reject(&:blank?)
    scope = ids.any? ? csv_resource.where(id: ids) : csv_resource.all
    cols  = csv_columns

    csv_data = CSV.generate(headers: true) do |csv|
      csv << cols.map { |c| c[:header] }
      scope.each do |record|
        csv << cols.map { |c| record.public_send(c[:attr]).to_s }
      end
    end

    send_data csv_data,
              filename: "#{csv_resource.table_name}_#{Date.today}.csv",
              type: 'text/csv',
              disposition: 'attachment'
  end

  # GET /resources/import_csv
  def import_csv
    @resource_name = csv_resource.model_name.human.pluralize
    @back_url      = url_for(action: :index)
    @import_url    = url_for(action: :process_import)
    @columns       = csv_columns
    render template: 'shared/import_csv'
  end

  # POST /resources/process_import
  def process_import
    file = params.dig(:csv_upload, :file)
    return redirect_to(url_for(action: :index), alert: 'Please select a CSV file.') unless file.present?

    tmp_path = Rails.root.join('tmp', "csv_import_#{SecureRandom.hex(8)}.csv")
    File.binwrite(tmp_path, file.read)
    session[:csv_import_file] = tmp_path.to_s

    cols     = csv_columns
    id_col   = cols.first
    editable = cols.reject { |c| c[:readonly] }

    @changes   = []
    @not_found = []
    @no_change = 0

    CSV.foreach(tmp_path, headers: true) do |row|
      raw_id = row[id_col[:header]]&.strip
      next if raw_id.blank?

      record = csv_resource.find_by(id: raw_id)
      unless record
        @not_found << raw_id
        next
      end

      diffs = editable.filter_map do |col|
        new_val = row[col[:header]]&.strip.to_s
        old_val = record.public_send(col[:attr]).to_s
        { col: col, old: old_val, new: new_val } if new_val.present? && csv_values_differ?(old_val, new_val)
      end

      if diffs.any?
        @changes << { record: record, diffs: diffs }
      else
        @no_change += 1
      end
    end

    @resource_name = csv_resource.model_name.human.pluralize
    @back_url      = url_for(action: :index)
    @confirm_url   = url_for(action: :confirm_import)
    render template: 'shared/preview_import'
  end

  # POST /resources/confirm_import
  def confirm_import
    file_path = session.delete(:csv_import_file)
    unless file_path && File.exist?(file_path)
      return redirect_to(url_for(action: :index), alert: 'Import session expired. Please re-upload.')
    end

    cols     = csv_columns
    id_col   = cols.first
    editable = cols.reject { |c| c[:readonly] }
    updated  = 0
    errors   = []

    CSV.foreach(file_path, headers: true) do |row|
      raw_id = row[id_col[:header]]&.strip
      next if raw_id.blank?

      record = csv_resource.find_by(id: raw_id)
      next unless record

      attrs = {}
      editable.each do |col|
        new_val = row[col[:header]]&.strip
        attrs[col[:attr]] = new_val if new_val.present?
      end
      next if attrs.empty?

      if record.update(attrs)
        csv_after_update(record, attrs)
        updated += 1
      else
        errors << "#{raw_id}: #{record.errors.full_messages.to_sentence}"
      end
    end

    File.delete(file_path) rescue nil

    noun = csv_resource.model_name.human.downcase.pluralize(updated)
    msg  = "Updated #{updated} #{noun}."
    msg += " Errors: #{errors.join('; ')}" if errors.any?
    redirect_to url_for(action: :index), notice: msg
  end

  private

  # Override in a controller to run custom logic after each row is successfully updated.
  def csv_after_update(record, attrs)
    # no-op by default
  end

  # Compare two string values, using numeric equality when both parse as numbers.
  # This prevents Excel's reformatting (e.g. "0.0" → "0") from appearing as a change.
  def csv_values_differ?(old_val, new_val)
    old_num = BigDecimal(old_val)
    new_num = BigDecimal(new_val)
    old_num != new_num
  rescue ArgumentError, TypeError
    old_val != new_val
  end
end
