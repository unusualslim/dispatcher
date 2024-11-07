namespace :import do
    desc "Import locations from Google Keep JSON file with transaction for easy rollback"
  
    task locations: :environment do
      # Path to your JSON file
      file_path = Rails.root.join('db', 'data', 'locations.json')
  
      # Check if the file exists
      unless File.exist?(file_path)
        puts "JSON file not found at #{file_path}"
        return
      end
  
      # Read and parse the JSON file
      file = File.read(file_path)
      data = JSON.parse(file)
  
      # Ensure we are working with the 'features' array
      features = data['features'] || []
      
      # Start a transaction for easy rollback
      Location.transaction do
        features.each do |entry|
          # Debugging output to understand the structure of entry
          puts "Processing entry: #{entry.inspect}"  # Log the entry being processed
  
          # Ensure the structure of geometry and coordinates is correct
          geometry = entry['geometry']
          if geometry && geometry['coordinates'].is_a?(Array) && geometry['coordinates'].size >= 2
            coordinates = geometry['coordinates']
            latitude = coordinates[1]
            longitude = coordinates[0]
          else
            puts "Skipping entry due to invalid or missing coordinates: #{entry.inspect}"
            next
          end

          if latitude == 0.0 || longitude == 0.0
            puts "Skipping location with invalid coordinates: Latitude #{latitude}, Longitude #{longitude}"
            next
          end
  
          # Extract properties and ensure location_info exists
          properties = entry['properties'] || {}
          location_info = properties['location'] || {}
  
          # Parse address to extract city, state, and zip
          location_address = location_info['address'] || ""
          address_parts = location_address.split(',').map(&:strip) # Split by commas and remove whitespace
          
          # Default values
          address = ''
          city = ''
          state = ''
          zip = ''
  
          if address_parts.size >= 3
            address = address_parts[0] # First part is the street address
            city = address_parts[1] # Second part is the city
            state_zip = address_parts[2].split(' ') # Split the state and zip
            
            state = state_zip[0] # First part of the last item is the state
            zip = state_zip[1] if state_zip.size > 1 # Second part (if exists) is the zip
          end
  
          # Additional properties
          date = properties['date']
          google_maps_url = properties['google_maps_url']
          comment = properties['Comment']
          company_name = location_info['name'] || "Unknown Company"  # Default if name is missing
  
          # Create the location with hard-coded location_category_id of 2
          Location.create!(
            latitude: latitude,
            longitude: longitude,
            location_category_id: 2,
            company_name: company_name,
            notes: comment,
            address: address, # Using the extracted address
            city: city,       # Using the extracted city
            state: state,     # Using the extracted state
            zip: zip,         # Using the extracted zip
            created_at: DateTime.parse(date)
          )
        end
  
        # Raise an error to roll back all changes for testing
      end
    end
  end
  