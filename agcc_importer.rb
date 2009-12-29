agcc_pickup_folder.check_every 5.minutes do
  age :greater_than => 1.minutes

  files_ending_with "ARR" do |file|
    move file, :to => agcc_dropoff_folder
  end
end
