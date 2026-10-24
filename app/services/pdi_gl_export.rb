require 'base64'

# Sends every approved ledger entry to PDI as one FPST GL import CSV over FTP, then marks them
# exported. Nothing is marked if the upload fails, so a retry resends the same entries.
class PdiGlExport
  include PdiFtpConcern

  PROCESS_NAME = 'PDI GL Export'.freeze
  FTP_DIR = ENV.fetch('PDI_FTP_GL_DIR', ENV.fetch('PDI_FTP_PATH', '/'))

  class NothingToExport < StandardError; end

  def self.filename(time = Time.current)
    "FPST_GL_#{time.strftime('%Y%m%d%H%M%S')}.csv"
  end

  def self.pending_entries
    LedgerEntry.pending_export.includes(:ledger_lines).order(:approved_at, :id)
  end

  def run
    entries = self.class.pending_entries.to_a
    raise NothingToExport, 'No approved entries waiting for export' if entries.empty?

    log = start_log(PdiGlImport.csv(entries))
    upload(log.file_name, log.file_content)
    finish(log, entries)
  rescue NothingToExport
    raise
  rescue StandardError => e
    log&.update!(status: 'failed', completed_at: Time.current, error_message: e.message)
    raise
  end

  private

  def start_log(content)
    SyncLog.create!(process_name: PROCESS_NAME, status: 'running', started_at: Time.current,
                    file_name: self.class.filename, file_content: content, file_binary: false)
  end

  def upload(filename, content)
    ftp_connect do |ftp|
      ftp.chdir(FTP_DIR) unless FTP_DIR == '/'
      ftp.storbinary("STOR #{filename}", StringIO.new(content), Net::FTP::DEFAULT_BLOCKSIZE)
    end
  end

  def finish(log, entries)
    LedgerEntry.transaction do
      entries.each { |e| e.update!(status: 'exported', exported_at: Time.current, sync_log: log) }
      log.update!(status: 'success', completed_at: Time.current, records_created: entries.size,
                  warnings: "Entries: #{entries.map(&:reference_number).join(', ')}")
    end
    entries.size
  end
end
