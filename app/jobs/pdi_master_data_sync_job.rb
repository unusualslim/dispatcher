require 'base64'
require 'zlib'

# Pulls PDI's master data from the Enterprise Web Service and syncs customers, ship-tos,
# terminal links and products (PdiMasterDataImportService). Off by default: review the first
# import at /pdi_master_data_import before giving it a schedule.
class PdiMasterDataSyncJob < ApplicationJob
  queue_as :default

  PROCESS_NAME = 'PDI Master Data Sync'.freeze
  FILE_NAME = 'pdi_master_data.xml.gz'.freeze

  ACTION_WORDS = { create: 'new', link: 'linked', update: 'updated' }.freeze

  def self.summary(result)
    PdiMasterDataImportService::SECTIONS.map do |section, title|
      counts = ACTION_WORDS.map { |action, word| [word, result.count(section, action)] }.reject { |_, n| n.zero? }
      "#{title}: #{counts.any? ? counts.map { |word, n| "#{n} #{word}" }.join(', ') : 'no changes'}"
    end.join("\n")
  end

  # Records an import (from the job or the manual import page) in a SyncLog.
  def self.import(xml, log)
    result = PdiMasterDataImportService.call(xml)
    log.update!(
      file_name: FILE_NAME, file_content: Base64.strict_encode64(Zlib.gzip(xml)), file_binary: true,
      status: 'success', completed_at: Time.current,
      records_created: result.total(:create), records_updated: result.total(:update) + result.total(:link),
      records_skipped: result.total(:skip),
      warnings: [summary(result), *result.errors].join("\n")
    )
    result
  end

  def perform
    log = SyncLog.create!(process_name: PROCESS_NAME, status: 'running', started_at: Time.current)
    unless PdiWebService.configured?
      return log.update!(status: 'skipped', completed_at: Time.current,
                         error_message: 'PDI web service credentials are not set')
    end

    self.class.import(PdiWebService.new.master_data, log)
  rescue StandardError => e
    log&.update!(status: 'failed', completed_at: Time.current, error_message: e.message)
    Rails.logger.error "[PdiMasterDataSyncJob] Failed: #{e.message}"
    raise
  end
end
