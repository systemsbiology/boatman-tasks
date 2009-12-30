def convert_agilentfe_to_analyzerdg(agilent_file_name, analyzer_file_name)
  #require 'rubygems';require 'ruby-debug';debugger
  agilent_file = File.open(agilent_file_name, "r")
  agilent_lines = agilent_file.readlines.collect {|line| line.split(/\t/)}

  # check the header first to make sure it's the right format
  data_header = agilent_lines[9]
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

  analyzer_file = File.open(analyzer_file_name, "w")

  fe_param_header = agilent_lines[1]
  fe_param_data = agilent_lines[2]

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

  analyzer_rows = agilent_columns * 2
  analyzer_columns = agilent_rows / 2

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
  agilent_lines[10..-1].each do |line|
    agilent_row = line[ column_lookup['Row'] ].to_i
    agilent_column = line[ column_lookup['Col'] ].to_i

    if agilent_row % 2 == 1
      analyzer_row = analyzer_rows - (agilent_column - 1) * 2;
      analyzer_column = analyzer_columns - ( (agilent_row + 1) / 2 - 1 );
    else
      analyzer_row = analyzer_rows - ( (agilent_column - 1) * 2 + 1 );
      analyzer_column = analyzer_columns - (agilent_row / 2 - 1);
    end

    data = [
      probe_number,
      1,
      1,
      1,
      1,
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
  agilent_file.close
  analyzer_file.close
end
