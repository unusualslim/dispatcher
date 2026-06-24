namespace :pdi do
  desc "Sync vendors from PDI FTP (AP Vendor List.csv)"
  task sync_vendors: :environment do
    puts "Starting PDI vendor sync..."
    PdiVendorSyncJob.perform_now
    puts "Done."
  end
end
