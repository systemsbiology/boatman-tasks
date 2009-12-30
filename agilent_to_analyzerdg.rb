require 'agilentfe'
require 'rest_client'

agilent_coordinates_to_array_number = {
  1 => { [nil,nil] => 1 },
  2 => { [1,1] => 2, [1,2] => 1 },
  4 => { [1,1] => 4, [1,2] => 3, [1,3] => 2, [1,4] => 1 },
  8 => { [1,1] => 8, [1,2] => 6, [1,3] => 4, [1,4] => 3,
         [2,1] => 7, [2,2] => 5, [2,3] => 2, [2,4] => 1 }
}

agilent_feature_extraction_output.check_every 5.minutes do
  age :greater_than => 2.minutes

  # handle QC PDFs
  files_matching(/(US\d{8}_(\d{12})|(\d{12})_\d{12})_.*_(\d)_(\d)*\.pdf/) do |file|
    barcode = match_data[2] || match_data[3]
    design_id = barcode.match(/\d{2}(\d{5})\d{5}/)[1]
    destination_folder = [agilent_quantitation_folder, design_id].join("/")

    copy file, :to => destination_folder
  end

  # handle actual data TXT files
  files_matching(/(US\d{8}_(\d{12})|(\d{12})_\d{12})_.*_(\d)_(\d)*\.txt/) do |file|
    match_data = file.match_data

    barcode = match_data[2] || match_data[3]
    agilent_coordinates = [match_data[4].to_i, match_data[5].to_i] if match_data[4] && match_data[5]

    design_id = barcode.match(/\d{2}(\d{5})\d{5}/)[1]
    destination_folder = [agilent_quantitation_folder, design_id].join("/")

    # determine array number
    arrays_per_slide = YAML.load_file("agilent_designs.yml")[design_id.to_i]

    if arrays_per_slide
      array_number = agilent_coordinates_to_array_number[arrays_per_slide][agilent_coordinates]

      # copy the raw Agilent FE text
      copy file, :to => destination_folder

      # let SLIMarray know about this new data file
      begin
        slimarray_resource = RestClient::Resource.new slimarray_raw_data_uri, :user => slimarray_user,
          :password => slimarray_password, :timeout => 20
        new_file_path = [destination_folder, File.basename(file.path)].join("/")
        slimarray_resource.post :chip_name => barcode, :array_number => array_number, :path => new_file_path
      rescue RestClient::ResourceNotFound => e
        Boatman.logger.debug "No match found in SLIMarray for barcode = #{barcode}, " + 
          "array number = #{array_number}"
      rescue StandardError => e
        Boatman.logger.error "Could not connect to SLIMarray web service: #{e.message}"
      end

      # convert the Agilent FE format file to an AnalyzerDG format CSV file
      analyzerdg_file_name = "#{barcode}#{array_number}.csv"
      copy file, :to => destination_folder, :rename => analyzerdg_file_name do |old_file_name, new_file_name|
        convert_agilentfe_to_analyzerdg(old_file_name, new_file_name)
      end
    else
      Boatman.logger.error "Missing coordinate information in agilent_designs.yml for design #{design_id}"
    end
  end
end
