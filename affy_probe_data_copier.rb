affy_instrument_data_folder.check_every 5.minutes do
  age :greater_than => 2.minutes

  files_matching /((\d{6})\d{2}_\d{2}_.*)\.(CEL|CHP|RPT|JPG)/i do |file|
    match_data = file.match_data
    file_name = match_data[0]
    file_root = match_data[1]
    date_folder = match_data[2]

    destination_folder = [ affy_probe_data_folder, date_folder ].join("/")
    standardized_file_path = [ affy_probe_data_folder, date_folder, file_name ].join("/")

    copy file, :to => destination_folder do |source_path, destination_path|
      FTPUtils.cp source_path, destination_path
      verify_checksum_matches(source_path, destination_path)

      # only for CEL files
      if /\.CEL$/.match(file_name)
        begin
          slimarray_resource = RestClient::Resource.new slimarray_raw_data_uri, :user => slimarray_user,
            :password => slimarray_password, :timeout => 20

          # hack to get POSIX path
          standardized_file_path.gsub!(/\//, '/').gsub!(/\/isb\-2\/Arrays/, 'net/arrays')        
          standardized_file_path.gsub!(/\//, '/').gsub!(/Volumes\/arrays/, 'net/arrays')        
          #puts "standardized_file_path: #{standardized_file_path}"
          
          slimarray_resource.post :chip_name => file_root, :array_number => 1, :path => standardized_file_path
        rescue RestClient::ResourceNotFound => e
          Boatman.logger.debug "No match found in SLIMarray for chip #{file_root}, " + 
            "array number = 1 path #{standardized_file_path}"
        rescue StandardError => e
          Boatman.logger.error "Could not connect to SLIMarray web service: #{e.message}"
        end
      end
    end
  end
end
