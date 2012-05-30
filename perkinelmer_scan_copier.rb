def subfolder(slide_number)
  slide_number = slide_number.to_i

  ending_number = (slide_number/100 + 1) * 100
  starting_number = ending_number - 99

  return "#{"%05d" % starting_number}-#{"%05d" % ending_number}"
end

perkinelmer_scans_folder.check_every 5.minutes do
  age :greater_than => 2.minutes

  # spotted arrays
  folders_matching /^(\d{5})_(\d{6})(_sybr)*$/ do |folder|
    match_data = folder.match_data

    slide_number = match_data[1]
    scan_date = match_data[2]

    folders_matching "Images" do |image_folder|
      files_ending_with "tif" do |tif_image|
        main_folder = subfolder(slide_number)
        slide_folder = [slide_number, scan_date].join("_")
        image_folder = "Images"
        
        new_image_name = slide_folder + "-" + File.basename(tif_image.path)
        new_image_path = [
          scan_storage_folder,
          main_folder,
          slide_folder,
          image_folder
        ].join("/")

        copy tif_image, :to => new_image_path, :rename => new_image_name
      end
    end
  end

  # Exiqon arrays
  folders_matching /^(\d{8})_(\d{6})$/ do |folder|
    match_data = folder.match_data

    slide_number = match_data[1]
    scan_date = match_data[2]

    folders_matching "Images" do |image_folder|
      files_ending_with "tif" do |tif_image|
        main_folder = "Exiqon"
        slide_folder = [slide_number, scan_date].join("_")
        image_folder = "Images"
        
        new_image_name = slide_folder + "-" + File.basename(tif_image.path)
        new_image_path = [
          scan_storage_folder,
          main_folder,
          slide_folder,
          image_folder
        ].join("/")

        copy tif_image, :to => new_image_path, :rename => new_image_name
      end
    end
  end

  # scans that aren't spotted arrays or Exiqon
  folders_matching /^(.*)$/ do |folder|
    base_name = File.basename(folder.path)
    next if base_name =~ /^(\d{5})_(\d{6})(_sybr)*$/ || base_name =~ /^(\d{8})_(\d{6})(_sybr)*$/

    match_data = folder.match_data

    slide_name = match_data[1]

    folders_matching "Images" do |image_folder|
      files_ending_with "tif" do |tif_image|
        image_folder = "Images"
        
        new_image_name = slide_name + "-" + File.basename(tif_image.path)
        new_image_path = [
          scan_storage_folder,
          "Other_Numbers",
          slide_name,
          image_folder
        ].join("/")

        copy tif_image, :to => new_image_path, :rename => new_image_name
      end
    end
  end
end
