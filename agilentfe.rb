require 'nokogiri'

def convert_agilentfe_to_analyzerdg(agilent_file_name, analyzer_file_name, orientation = :agilent,
                                   zone_rows=1, zone_columns=1)
  #require 'rubygems';require 'ruby-debug';debugger
  # can't check if this exists because it's on a remote host
  agilent_file = open(agilent_file_name, "r")
  agilent_file.gets

  fe_param_header = split_tabs(agilent_file.gets)
  fe_param_data = split_tabs(agilent_file.gets)

  # skip the next 6 lines
  6.times{ agilent_file.gets }

  # check the header first to make sure it's the right format
  data_header = split_tabs(agilent_file.gets)
  column_lookup = Hash.new
  (0..data_header.size-1).each do |n|
    column_lookup[data_header[n]] = n
  end
  required_metrics = ["gIsSaturated","gNumSatPix","gNumPix","gMeanSignal","gMedianSignal","gPixSDev",
   "gBGMeanSignal","gBGMedianSignal","gBGPixSDev","gBGNumPix"]
  required_metrics.each do |metric|
    unless column_lookup[metric]
      raise "Agilent FE file is missing metric: #{metric}"
    end
  end

  #writing the new file
  analyzer_file = File.open(analyzer_file_name, "w")

  channel_number = fe_param_data[ fe_param_header.index("Scan_NumChannels") ].to_i

  # ASSUMPTION: 1-channel is alway Cy3, 2-channels Cy3+Cy5
  case channel_number
  when 1
    channel_names = ["Cyanine3"]
    channel_prefixes = ["g"]
  when 2
    channel_names = ["Cyanine3","Cyanine5"]
    channel_prefixes = ["g","r"]
  end

  agilent_rows = fe_param_data[ fe_param_header.index("Grid_NumRows") ].to_i
  agilent_columns = fe_param_data[ fe_param_header.index("Grid_NumCols") ].to_i

  #puts "Agilent dimensions: #{agilent_rows} x #{agilent_columns}"

  case orientation
  when :standard
    analyzer_rows = agilent_rows
    analyzer_columns = agilent_columns

    analyzer_grid_rows = analyzer_rows / zone_rows
    analyzer_grid_columns = analyzer_columns / zone_columns
  when :agilent
    analyzer_rows = agilent_columns * 2
    analyzer_columns = agilent_rows / 2

    analyzer_grid_rows = analyzer_rows
    analyzer_grid_columns = analyzer_columns
  else
    raise "Orientation must be either standard or agilent, but was #{orientation}"
  end

  #puts "Geometry: #{zone_rows} x #{zone_columns} -> #{analyzer_grid_rows} x #{analyzer_grid_columns}"

  ####################
  # output headings
  ####################
  coordinate_headings = "Number,Multi-Set Row,Multi-Set Column,Set Row,Set Column,Row,Column,"
  channel_metrics = ["Spot Confidence", "Spot Saturation (%)", "Spot Mean Intensity", 
               "Spot Median Intensity", "Spot Total Intensity", "Spot Standard Deviation",
               "Spot Number of Pixels", "Background Mean Intensity", "Background Median Intensity", 
               "Background Standard Deviation", "Background Number of Pixels"]
  channel_headings = channel_metrics.collect do |metric|
    channel_names.collect {|channel| "#{metric} (#{channel})"}
  end
  channel_headings.flatten!

  analyzer_file << coordinate_headings + channel_headings.join(",") + "\n"

  ####################
  # output data
  ####################
  
  probe_number = 1
  while raw_line = agilent_file.gets
    line = split_tabs(raw_line)

    zone_row = 1
    zone_column = 1

    agilent_row = line[ column_lookup['Row'] ].to_i
    agilent_column = line[ column_lookup['Col'] ].to_i

    if orientation == :standard
      zone_row = (agilent_row-1) / analyzer_grid_rows + 1
      zone_column = (agilent_column-1) / analyzer_grid_columns + 1

      analyzer_row = (agilent_row-1) % analyzer_grid_rows + 1
      analyzer_column = (agilent_column-1) % analyzer_grid_columns + 1
    elsif agilent_row % 2 == 1
      zone_row = 1
      zone_column = 1

      analyzer_row = analyzer_rows - (agilent_column - 1) * 2
      analyzer_column = analyzer_columns - ( (agilent_row + 1) / 2 - 1 )
    else
      zone_row = 1
      zone_column = 1

      analyzer_row = analyzer_rows - ( (agilent_column - 1) * 2 + 1 )
      analyzer_column = analyzer_columns - (agilent_row / 2 - 1)
    end

    data = [
      probe_number,
      1,
      1,
      zone_row,
      zone_column,
      analyzer_row,
      analyzer_column,
      channel_prefixes.collect {|p| line[ column_lookup["#{p}IsSaturated"] ] == "1" ? "0" : "100"},
      channel_prefixes.collect {|p|
        line[ column_lookup["#{p}NumSatPix"] ].to_f / line[ column_lookup["#{p}NumPix"] ].to_f * 100},
      channel_prefixes.collect {|p| line[ column_lookup["#{p}MeanSignal"] ]},
      channel_prefixes.collect {|p| line[ column_lookup["#{p}MedianSignal"] ]},
      channel_prefixes.collect {|p|
        line[ column_lookup["#{p}MeanSignal"] ].to_f * line[ column_lookup["#{p}NumPix"] ].to_f},
      channel_prefixes.collect {|p| line[ column_lookup["#{p}PixSDev"] ]},
      channel_prefixes.collect {|p| line[ column_lookup["#{p}NumPix"] ]},
      channel_prefixes.collect {|p| line[ column_lookup["#{p}BGMeanSignal"] ]},
      channel_prefixes.collect {|p| line[ column_lookup["#{p}BGMedianSignal"] ]},
      channel_prefixes.collect {|p| line[ column_lookup["#{p}BGPixSDev"] ]},
      channel_prefixes.collect {|p| line[ column_lookup["#{p}BGNumPix"] ]}
    ]

    analyzer_file << data.join(",") + "\n"

    probe_number += 1
  end

  # see if this incantation prevents permission denied error on subsequent 
  # attempts to access the file
  analyzer_file.close
  sleep 1
end

def split_tabs(text)
  return text.split(/\t/)
end

class AgilentQC
  def self.parse(path, agilent_coordinates)
    metric_names = ["gNonCtrlNumSatFeat", "rNonCtrlNumSatFeat", "Metric_gNonCntrlMedCVProcSignal", "Metric_rNonCntrlMedCVProcSignal"]

    file = open(path)
    doc = Nokogiri::XML(file)

    arrays = doc.xpath("/FeatureExtractionML/FEProjectResults/Extraction/Arrays/Array")
    
    statistics = Hash.new
    arrays.each do |array|
      next unless array.get_attribute("ID").match(/#{agilent_coordinates}$/)

      metric_names.each do |metric_name|
        if stat = array.xpath("StatsTable/Stat[@name='#{metric_name}']").first
          statistics[metric_name] = stat.get_attribute :value
        end
      end
    end

    return statistics
  end
end
