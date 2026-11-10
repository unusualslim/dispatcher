namespace :pdi do
  desc 'Re-import a saved PDI Order API Sync feed: rake pdi:reimport_orders[SYNC_LOG_ID]'
  task :reimport_orders, [:log_id] => :environment do |_, args|
    source = SyncLog.find(args.fetch(:log_id))
    xml = Zlib.gunzip(Base64.strict_decode64(source.file_content))
    log = SyncLog.create!(process_name: PdiOrderApiSyncJob::PROCESS_NAME, status: 'running', started_at: Time.current,
                          file_name: source.file_name, file_content: source.file_content, file_binary: true)
    result = PdiOrderApiSyncJob.import(xml, log)
    puts "Created #{result.created}, updated #{result.updated}, unchanged #{result.unchanged}, " \
         "errors #{result.errors.size}"
  end

  desc 'Fetch PDI fuel loads delivered in a date range: rake pdi:sync_fuel_loads[2026-06-01,2026-11-10]'
  task :sync_fuel_loads, %i[from to] => :environment do |_, args|
    PdiFuelLoadSyncJob.perform_now(from: args.fetch(:from), to: args[:to])
    log = SyncLog.for_process(PdiFuelLoadSyncJob::PROCESS_NAME).first
    puts "#{log.status}: created #{log.records_created}, updated #{log.records_updated}, " \
         "unchanged #{log.records_skipped} #{log.warnings}"
  end

  desc 'Sync vendors from PDI FTP (AP Vendor List.csv)'
  task sync_vendors: :environment do
    puts 'Starting PDI vendor sync...'
    PdiVendorSyncJob.perform_now
    puts 'Done.'
  end

  desc 'List FTP directory structure (for debugging path issues)'
  task ftp_ls: :environment do
    require 'net/ftp'
    host     = ENV.fetch('PDI_FTP_HOST')
    user     = ENV.fetch('PDI_FTP_USER')
    password = ENV.fetch('PDI_FTP_PASSWORD')

    Net::FTP.open(host, username: user, password: password) do |ftp|
      ftp.passive = true
      puts "Root: #{ftp.pwd}"
      puts ftp.list.join("\n")
      puts "\n--- trying Imports ---"
      begin
        ftp.chdir('Imports')
        puts "pwd: #{ftp.pwd}"
        puts ftp.list.join("\n")
      rescue StandardError => e
        puts "Imports failed: #{e.message}"
      end
    end
  end
end
