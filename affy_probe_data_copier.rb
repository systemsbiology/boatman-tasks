affy_instrument_data_folder.check_every 5.minutes do
  age :greater_than => 2.minutes

  files_matching /(\d{6})(\d{2})_(\d{2})_(.*)\.(CEL|CHP|RPT|JPG)/i do |file|
    match_data = file.match_data

    destination_path = [ affy_probe_data_folder, match_data[1] ].join("/")

    copy file, :to => destination_path
  end
end
