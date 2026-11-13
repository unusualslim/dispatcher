# Data Imports → Tank Feeds: a feed's file uploaded by hand (to try a feed before its pickup job is turned on,
# re-import a file, or load the spreadsheet history CSV from `rake tanks:spreadsheet_csv`). Preview, then import.
class TankFeedImportsController < ApplicationController
  before_action :require_admin!
  before_action :require_feed_and_file, only: :preview

  FEEDS = FeedTank::FEEDS.except('manual').freeze
  SESSION_KEY = :tank_feed_import

  def self.process_name(feed)
    "Tank Feed Import (#{FeedTank::FEEDS[feed]})" if FEEDS.key?(feed)
  end

  def new
    @logs = SyncLog.where(process_name: FEEDS.keys.map { |f| self.class.process_name(f) }).recent.limit(20)
  end

  def preview
    @upload = save_upload(params[:file])
    @summary = importer(@upload).summary
  rescue ArgumentError, CSV::MalformedCSVError => e
    redirect_to new_tank_feed_import_path, alert: e.message
  end

  def create
    upload = session[SESSION_KEY]&.symbolize_keys
    return redirect_to new_tank_feed_import_path, alert: t('.expired') unless upload && File.exist?(upload[:path].to_s)

    redirect_to new_tank_feed_import_path, run_import(upload)
  end

  def download
    log = SyncLog.find(params[:log_id])
    return redirect_to new_tank_feed_import_path, alert: t('.unavailable') if log.file_content.blank?

    send_data log.file_content, type: 'text/plain', disposition: "attachment; filename=\"#{log.file_name}\""
  end

  private

  def require_feed_and_file
    @feed = params[:feed].presence_in(FEEDS.keys)
    redirect_to new_tank_feed_import_path, alert: t('tank_feed_imports.preview.choose') unless @feed && params[:file]
  end

  def importer(upload)
    read_at = Time.find_zone!(TankFeeds::Base::EASTERN).parse(upload[:read_at].to_s) if upload[:read_at].present?
    TankFeeds.for(upload[:feed], upload[:path], file_name: upload[:file_name], read_at: read_at)
  end

  # Keeps the upload until the import is confirmed.
  def save_upload(file)
    session[SESSION_KEY] = { feed: @feed, path: write_tempfile(file), file_name: file.original_filename,
                             read_at: params[:read_at].presence }
    session[SESSION_KEY].symbolize_keys
  end

  def write_tempfile(file)
    tmp = Tempfile.new(['tank_feed', File.extname(file.original_filename.to_s)])
    tmp.binmode
    tmp.write(file.read)
    tmp.flush
    ObjectSpace.undefine_finalizer(tmp)
    tmp.path
  end

  # Returns the flash for the redirect.
  def run_import(upload)
    log = start_log(upload)
    finish_log(log, importer(upload).import!(sync_log: log))
  rescue StandardError => e
    log&.update!(status: 'failed', completed_at: Time.current, error_message: e.message)
    { alert: t('tank_feed_imports.create.failed', message: e.message) }
  ensure
    clear_upload(upload)
  end

  def start_log(upload)
    SyncLog.create!(process_name: self.class.process_name(upload[:feed]), status: 'running', started_at: Time.current,
                    file_binary: false, file_name: upload[:file_name], file_content: File.read(upload[:path]).scrub)
  end

  def finish_log(log, result)
    log.update!(status: 'success', completed_at: Time.current, records_created: result[:created],
                records_updated: result[:updated], records_skipped: result[:skipped],
                warnings: result[:warnings].join("\n").presence)
    { notice: t('tank_feed_imports.create.done', count: result[:created], tanks: result[:updated]) }
  end

  def clear_upload(upload)
    FileUtils.rm_f(upload[:path])
    session.delete(SESSION_KEY)
  end
end
