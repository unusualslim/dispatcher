namespace :pdi do
  desc "Sync vendors from PDI FTP (AP Vendor List.csv)"
  task sync_vendors: :environment do
    puts "Starting PDI vendor sync..."
    PdiVendorSyncJob.perform_now
    puts "Done."
  end

  desc "List FTP directory structure (for debugging path issues)"
  task ftp_ls: :environment do
    require 'net/ftp'
    host     = ENV.fetch('PDI_FTP_HOST')
    user     = ENV.fetch('PDI_FTP_USER')
    password = ENV.fetch('PDI_FTP_PASSWORD')

    Net::FTP.open(host, username: user, password: password) do |ftp|
      ftp.passive = true
      puts "Root: #{ftp.pwd}"
      puts ftp.list.join("\n")
      puts "\n--- trying EnterpriseData ---"
      begin
        ftp.chdir('EnterpriseData')
        puts "pwd: #{ftp.pwd}"
        puts ftp.list.join("\n")
      rescue => e
        puts "EnterpriseData failed: #{e.message}"
      end
    end
  end
end
