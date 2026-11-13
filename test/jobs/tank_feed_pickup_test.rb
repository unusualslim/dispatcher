require 'test_helper'
require Rails.root.join('test/support/tank_feed_files').to_s

# Tank feed pickups from PDI FTP /Imports.
class TankFeedPickupTest < ActiveSupport::TestCase
  include TankFeedFiles

  # Just enough of Net::FTP, with file times.
  class FakeFtp
    attr_reader :files, :deleted

    def initialize(files, mtimes = {})
      @files = files
      @mtimes = mtimes
      @deleted = []
    end

    def chdir(_dir) = nil
    def nlst = files.keys
    def mtime(name) = @mtimes.fetch(name, 1.hour.ago)

    def delete(name)
      files.delete(name)
      deleted << name
    end

    def retrbinary(cmd, _size)
      yield files.fetch(cmd.delete_prefix('RETR '))
    end
  end

  def run_job(job_class, ftp)
    job = job_class.new
    job.define_singleton_method(:ftp_connect) { |&block| block.call(ftp) }
    job.perform_now
  end

  test '0002: a saved .eml email is picked up and read by its sent time' do
    ftp = FakeFtp.new('FPS_TANKS_0002_20261109.eml' => plant_0002_email)
    run_job(TankPlant0002SyncJob, ftp)

    assert_equal ['FPS_TANKS_0002_20261109.eml'], ftp.deleted
    log = SyncLog.find_by!(process_name: '0002 Tank Email Sync')
    assert_equal 'success', log.status
    assert_equal [Time.find_zone('America/New_York').local(2026, 11, 8, 23, 54, 54)],
                 TankReading.where(sync_log: log).distinct.pluck(:read_at)
  end

  test '0002: .txt files, reading time from the name, readings linked to the log' do
    ftp = FakeFtp.new('FPS_TANKS_0002_20261111_0600.txt' => PLANT_0002, 'FPS_SMARTANK_20261111_0305.csv' => SMARTANK)
    run_job(TankPlant0002SyncJob, ftp)

    assert_equal ['FPS_TANKS_0002_20261111_0600.txt'], ftp.deleted
    log = SyncLog.find_by!(process_name: TankPlant0002SyncJob::PROCESS_NAME)
    assert_equal 4, log.records_created
    assert_equal [log.id], TankReading.distinct.pluck(:sync_log_id)
    assert_equal [Time.find_zone('America/New_York').local(2026, 11, 11, 6)], TankReading.distinct.pluck(:read_at)
  end

  test 'a file still uploading waits for the next run' do
    ftp = FakeFtp.new({ 'KII_20261111_17.csv' => KII }, { 'KII_20261111_17.csv' => 30.seconds.ago })
    run_job(TankKiiSyncJob, ftp)

    assert_empty ftp.deleted
    assert_equal 'skipped', SyncLog.find_by!(process_name: TankKiiSyncJob::PROCESS_NAME).status
  end

  test 'Kii keeps its stored files for two weeks' do
    old = SyncLog.create!(process_name: TankKiiSyncJob::PROCESS_NAME, status: 'success', started_at: 20.days.ago,
                          file_name: 'KII_old.csv', file_content: KII)
    run_job(TankKiiSyncJob, FakeFtp.new('KII_20261111_17.csv' => KII))

    assert_nil old.reload.file_content
    assert_equal 1, FeedTank.where(feed: 'kii', ignored: false).joins(:readings).distinct.count
  end

  test 'each pickup job is listed on Automated Processes under its own name, Off at first' do
    jobs = [TankKiiSyncJob, TankSmartankSyncJob, TankPlant0002SyncJob]
    listed = AutomatedProcessesController::PROCESSES.select { |p| p[:job].start_with?('Tank') }
    assert_equal jobs.map(&:name), listed.pluck(:job)
    assert_equal jobs.map { |job| job::PROCESS_NAME }, listed.pluck(:name)
    assert(listed.all? { |p| p[:default_schedule] == '' })
  end
end
