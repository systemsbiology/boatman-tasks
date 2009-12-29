def subfolder(slide_number)
  slide_number = slide_number.to_i

  ending_number = (slide_number/100 + 1) * 100
  starting_number = ending_number - 99

  return "#{"%05d" % starting_number}-#{"%05d" % ending_number}"
end

agilent_split_scans_folder.check_every 5.minutes do
  age :greater_than => 2.minutes

  files_matching /(\d{5})_\d{2}(\d{6})(\d{4})_S01_(L|H)_(R|G)\.tif/ do |file|
    match_data = file.match_data

    slide_number = match_data[1]
    scan_date = match_data[2]
    scan_intensity = match_data[4]

    # since Agilent only tells us red or green, assume Cy3/Cy5
    scan_color = match_data[5] == "R" ? "Cyanine5" : "Cyanine3"

    main_folder = subfolder(slide_number)
    slide_folder = [slide_number, scan_date].join("_")
    image_folder = "Images"
    
    new_image_name = slide_folder + "-" + scan_color + scan_intensity + ".tif"
    new_image_path = [
      scan_storage_folder,
      main_folder,
      slide_folder,
      image_folder
    ].join("/")

    copy file, :to => new_image_path, :rename => new_image_name
  end
end
