namespace :pdi do
  desc "One-time import of PDI warehouse transaction history into inventory_transactions"
  task import_warehouse_transactions: :environment do
    path = ENV['FILE'] || Rails.root.join('tmp', 'warehouse_transactions.xls').to_s

    unless File.exist?(path)
      puts "ERROR: File not found at #{path}"
      puts "Usage: rake pdi:import_warehouse_transactions FILE=/path/to/file.xls"
      exit 1
    end

    existing = InventoryTransaction.where("notes LIKE '[PDI Historical Import]%'").count
    if existing > 0
      puts "WARNING: #{existing} PDI historical transactions already exist."
      print "Re-run anyway? (y/N): "
      response = $stdin.gets.chomp
      unless response.downcase == 'y'
        puts "Aborted."
        exit 0
      end
    end

    puts "Importing from #{path}..."
    result = WarehouseTransactionImportService.call(path)

    puts ""
    puts "Done."
    puts "  Imported:              #{result.imported}"
    puts "  Skipped (no product):  #{result.skipped_no_product}"
    puts "  Skipped (unknown type):#{result.skipped_unknown_type}"
    puts "  Skipped (duplicate):   #{result.skipped_duplicate}"

    if result.errors.any?
      puts ""
      puts "Errors (#{result.errors.count}):"
      result.errors.each { |e| puts "  #{e}" }
    end
  end
end
