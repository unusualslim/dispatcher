require 'tempfile'

# Picks up CSVs that the user's nightly PDI SQL Server job uploads to the PDI FTP (FPS_<NAME>_<yyyymmdd>.csv),
# oldest first, runs the import on each, records one SyncLog per file (with the file kept for download) and
# deletes the file from FTP once it imported. A file that fails stays on FTP and is retried on the next run.
#
# Including jobs define PROCESS_NAME, FILE_PREFIX (e.g. 'FPS_PO_LINES') and #import(path) returning
# { created:, updated:, skipped:, warnings: [] }.
module PdiCsvPickup
  extend ActiveSupport::Concern
  include PdiFtpConcern

  included do
    queue_as :default
  end

  class_methods do
    def ftp_dir
      ENV.fetch('PDI_FTP_SQL_EXPORT_DIR', '/Imports')
    end

    # FPS_PO_LINES.csv, FPS_PO_LINES_20261105.csv, fps_po_lines-2026-11-05.csv …
    def matches?(filename)
      File.basename(filename).match?(/\A#{Regexp.escape(self::FILE_PREFIX)}([_-].*)?\.csv\z/i)
    end
  end

  def perform
    with_run_lock do
      files = waiting_files
      return skip_run if files.empty?

      files.each { |filename| pick_up(filename) }
    end
  end

  private

  # One run of a process at a time: a second run (the scheduler ticking again, or "Run now" during a scheduled run)
  # would read the same waiting files and race the first one. Held on the database connection (a Postgres advisory
  # lock), so it frees itself if the process dies. A run that finds it taken logs a skip and leaves the files alone.
  def with_run_lock
    key = Zlib.crc32(self.class::PROCESS_NAME)
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      locked = connection.select_value(ActiveRecord::Base.sanitize_sql(['SELECT pg_try_advisory_lock(?)', key]))
      return skip_busy unless locked

      begin
        yield
      ensure
        connection.execute(ActiveRecord::Base.sanitize_sql(['SELECT pg_advisory_unlock(?)', key]))
      end
    end
  end

  def skip_busy
    SyncLog.create!(process_name: self.class::PROCESS_NAME, status: 'skipped', started_at: Time.current,
                    completed_at: Time.current, error_message: 'Another run of this process is already working')
  end

  def waiting_files
    in_export_dir { |ftp| ftp.nlst.map { |f| File.basename(f) }.select { |f| self.class.matches?(f) }.sort }
  end

  def skip_run
    SyncLog.create!(process_name: self.class::PROCESS_NAME, status: 'skipped', started_at: Time.current,
                    completed_at: Time.current,
                    error_message: "No #{self.class::FILE_PREFIX}*.csv files in #{self.class.ftp_dir}")
  end

  def pick_up(filename)
    log = start_log(filename)
    content = in_export_dir { |ftp| ftp_download_text(ftp, filename) }
    log.update!(file_content: content)
    finish(log, import_text(content))
    in_export_dir { |ftp| ftp_delete(ftp, filename) }
  rescue StandardError => e
    log&.update!(status: 'failed', completed_at: Time.current, error_message: e.message)
    Rails.logger.error "[#{self.class.name}] #{filename} failed: #{e.message}"
  end

  def start_log(filename)
    SyncLog.create!(process_name: self.class::PROCESS_NAME, status: 'running', started_at: Time.current,
                    file_name: filename, file_binary: false)
  end

  def in_export_dir
    ftp_connect do |ftp|
      ftp.chdir(self.class.ftp_dir)
      yield ftp
    end
  end

  def import_text(content)
    Tempfile.create([self.class::FILE_PREFIX.downcase, '.csv'], binmode: true) do |file|
      file.write(content)
      file.flush
      import(file.path)
    end
  end

  def finish(log, result)
    log.update!(status: 'success', completed_at: Time.current, records_created: result[:created],
                records_updated: result[:updated], records_skipped: result[:skipped],
                warnings: Array(result[:warnings]).join("\n").presence)
  end
end
