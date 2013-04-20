require 'json'
require './snow-day'
require './resort'
require 'debugger'

def get_date_array(start_year)
	date_array = []
	30.times do |i|
		date_array.push (start_year * 10000) + 1100 + i + 1
	end
	31.times do |i|
		date_array.push (start_year * 10000) + 1200 + i + 1
	end
	31.times do |i|
		date_array.push ((start_year + 1) * 10000) + 100 + i + 1
	end
	28.times do |i|
		date_array.push ((start_year + 1) * 10000) + 200 + i + 1
	end
	31.times do |i|
		date_array.push ((start_year + 1) * 10000) + 300 + i + 1
	end
	30.times do |i|
		date_array.push ((start_year + 1) * 10000) + 400 + i + 1
	end
	date_array
end

$data_map = {}
def return_and_write_data_map()
	resort_map = {}
	SnowDay.all.each do |day|
		resort_name = day.resort_name
		season = day.season_name

		resort_map[resort_name] = {} if !resort_map[resort_name]
		resort_map[resort_name][season] = {} if !resort_map[resort_name][season]
		resort_map[resort_name][season][day.season_day] = {
			:d => day.date_string,
			:b => day.base
		}
	end
	# timestamp = Time.new.to_s.gsub(/[\s\-\:]/, "")[0..11]
	# File.open('json/' + timestamp + '.json', 'w') do |f|
	# 	f.write(resort_map.to_json)
	# end
	# p 'wrote ' + timestamp + '.json'
	resort_map
end

def normalize_data()
	p 'starting to build data map'
	$data_map = {}
	#Get list of resorts and go through each
	SnowDay.distinct(:resort_name).each do |resort_name|
		$data_map[resort_name] = {'average' => {}}

		#initialize the prev_date var so we can check for dupes
		prev_date = nil

		#Loop through all snowdays for each resort
		snowdays = SnowDay.where(:resort_name => resort_name).order_by(:date.asc)
		if snowdays.length == 0
			p 'no snowdays found for ' + resort_name
			next
		end
		first_year = nil

		snowdays.each do |day|
			#skip if snow day is an average and not an actual day belonging to a season
			if day.season_name == 'Average'
				$data_map[resort_name]['average'][day.season_day] = day
				next
			end

			if day.date == nil
				p 'day with null date found, destroying'
				day.destroy
				next
			end
			date = day.date
			date_string = day.date_string
			if first_year == nil ; first_year = date.year ; end

			# Delete days outside of the season, or if it's feb 29. Start season in Nov and end in april
			if (date.month < 11 && date.month > 4) || (date.month == 2 && date.day == 29)
				p 'destroying day outside season for ' + resort_name + ': ' + date_string.to_s
				p day.inspect
				day.destroy
				next
			end

			begin
				#delete days jan of first year so we don't have partial data
				if date.year == first_year && date.month < 11
					p 'destroying day because it has partial data from first year in dataset' + resort_name + ': ' + date_string.to_s
					day.destroy
					next
				end
			rescue Exception => e
				p 'error'
				p e.inspect
				p e.backtrace
				p day.inspect
			end

			# Delete duplicates
			if date_string == prev_date
				p 'destroying duplicate day ' + resort_name + ': ' + date_string.to_s
				day.destroy
				next
			end

			# if day.season_start_year == nil || day.season_name == nil
				# Populate season
				if date.month > 10
					season_start_year = date.year
					season_end_year = date.year + 1
				elsif date.month < 5
					season_start_year = date.year - 1
					season_end_year = date.year
				end
				season_name = season_start_year.to_s + '-' + season_end_year.to_s.slice(-2,2)
				day.update_attributes(
					season_start_year: season_start_year,
					season_end_year: season_end_year,
					season_name: season_name
				)
			# end

			$data_map[resort_name][season_name] = {} if !$data_map[resort_name][season_name]
			$data_map[resort_name][season_name][date_string] = day
		end
	end
	p 'built data map'
	$data_map
end

def build_season_data
	log = Logger.new('logs/data_processor_log.txt')
	log.level = Logger::WARN
	log.error('Start processing')

	p 'starting to build season data'
	data_map = normalize_data()
	averages_map = {}
	averages_denom_map = {}
	if data_map == nil
		p 'no data map returned'
		return
	end

	#Get list of resorts and go through each
	resort_names = SnowDay.distinct(:resort_name)

	#Go through each resort
	resort_names.each do |resort_name|
		p 'building season data for ' + resort_name
		averages_map[resort_name] = {}
		averages_denom_map[resort_name] = {}
		resort_id = Resort.where(:name => resort_name).first._id
		snow_days = SnowDay.where(:resort_name => resort_name).order_by(:date.asc)
		season_start_years = snow_days.distinct(:season_start_year)

		#Go through list of seasons
		season_start_years.each do |season_start_year|
			
			#populate array of season dates we want to check against
			date_array = get_date_array(season_start_year)

			#find all the days in the season
			season_data = snow_days.where(:season_start_year => season_start_year)

			first_date_string = season_data[0].date_string
			last_date_string = season_data[-1].date_string
			previous_found_date_string = first_date_string	
			season_name = season_start_year.to_s + '-' + (season_start_year + 1).to_s.slice(-2,2)
			missing_dates = []
			missing_date_strings = []
			missing_season_days = []
			season_day = 0

			#Go through each season day
			date_array.each do |date_string|
				season_day+=1

				begin
					if !data_map[resort_name] || !data_map[resort_name][season_name]
						p 'no data found for ' + resort_name + ' season starting in ' + season_start_year
						next
					end
					#check if we have a snowday in our array
					if !data_map[resort_name][season_name][date_string]
						str = date_string.to_s
						date = Date.new(str.slice(0,4).to_i, str.slice(4,2).to_i, str.slice(6,2).to_i)

						#check if we need to create days to pad the start and end of the season
						if date_string > last_date_string || date_string < first_date_string
							
							season_snow = date_string > last_date_string ? data_map[resort_name][season_name][last_date_string].season_snow : 0
							new_day = SnowDay.create(
								resort_name: resort_name,
								date_string: date_string,
								date: date,
								resort_id: resort_id,
								base: 0,
								precipitation: 0,
								season_snow: season_snow,
								generated: true,
								season_day: season_day,
								season_start_year: season_start_year,
								season_end_year: season_start_year + 1,
								season_name: season_name
							)

							averages_map[resort_name][season_day] = 0
							averages_denom_map[resort_name][season_day] = 0

							p 'saved new padding snow day for ' + resort_name + ': ' + date_string.to_s
						else
							#day is missing and in the middle of the first and last dates in the season, so push to missing date array to keep running tally
							missing_dates.push date
							missing_date_strings.push date_string
							missing_season_days.push season_day
						end
					else
						#We found a snowday

						# Make sure data isn't way off, and destroy document if the change in snow base is over 40. Also make sure we don't destroy days we just created
						base_diff = data_map[resort_name][season_name][date_string].base - data_map[resort_name][season_name][previous_found_date_string].base
						if (base_diff > 40 || base_diff < -40) && !data_map[resort_name][season_name][date_string].generated
							p 'deleting snowday for ' + resort_name + ': ' + date_string.to_s + ' because data is way off. difference of ' + base_diff.to_s

							# push to missing date array to keep running tally
							str = date_string.to_s
							date = Date.new(str.slice(0,4).to_i, str.slice(4,2).to_i, str.slice(6,2).to_i)
							missing_dates.push date
							missing_date_strings.push date_string
							missing_season_days.push season_day

							SnowDay.where(:resort_name => resort_name, :date_string => date_string).destroy

							next
						end

						#add a seasonday attribute
						data_map[resort_name][season_name][date_string].update_attributes(
							season_day: season_day
						)

						#add value to the averages map
						if data_map[resort_name][season_name][date_string].base > 0
							averages_map[resort_name][season_day] = data_map[resort_name][season_name][date_string].base + ( averages_map[resort_name][season_day] ? averages_map[resort_name][season_day] : 0)
							averages_denom_map[resort_name][season_day] = 1 + ( averages_denom_map[resort_name][season_day] ? averages_denom_map[resort_name][season_day] : 0)
						else 
							averages_map[resort_name][season_day] = 0
							averages_denom_map[resort_name][season_day] = 0
						end

						#check if we have a queue of missing days, and then fill out the dates in between
						if missing_dates.length > 0
							# if season_name == '2012-13' then debugger end
							season_snow_diff = data_map[resort_name][season_name][date_string].season_snow - data_map[resort_name][season_name][previous_found_date_string].season_snow
							if season_snow_diff < 0 ; season_snow_diff = 0 ; end

							incremental_base_diff = base_diff.to_f / (missing_dates.length + 1)
							incremental_season_snow_diff = season_snow_diff.to_f / (missing_dates.length + 1)
							i = -1
							p 
							missing_dates.each do |date|
								i+=1
								base = data_map[resort_name][season_name][previous_found_date_string].base + ((i + 1) * incremental_base_diff)
								season_day = missing_season_days[i]
								new_day = SnowDay.create(
									resort_name: resort_name,
									date_string: missing_date_strings[i],
									date: date,
									resort_id: resort_id,
									base: base,
									season_day: season_day,
									precipitation: 0,
									season_snow: data_map[resort_name][season_name][previous_found_date_string].season_snow + ((i + 1) * incremental_season_snow_diff),
									generated: true,
									season_start_year: season_start_year,
									season_end_year: season_start_year + 1,
									season_name: season_name
								)
								#add value to the averages map
								if base > 0
									averages_map[resort_name][season_day] = base + ( averages_map[resort_name][season_day] ? averages_map[resort_name][season_day] : 0)
									averages_denom_map[resort_name][season_day] = 1 + ( averages_denom_map[resort_name][season_day] ? averages_denom_map[resort_name][season_day] : 0)
								else 
									averages_map[resort_name][season_day] = 0
									averages_denom_map[resort_name][season_day] = 0
								end

								p 'saved new interpolated snow day for ' + resort_name + ': ' + missing_date_strings[i].to_s
							end
							missing_dates = []
							missing_date_strings = []
							missing_season_days = []
						end
						#Populate the previousDayString so we can know where the start point is for the interpolation
						previous_found_date_string = date_string
					end
				rescue Exception => e
					p 'Error with ' + resort_name + ': ' + date_string.to_s
					p e.inspect
					p e.backtrace
				end
			end
		end

		#calculate averages
		# debugger
		averages_map.each do |resort_name, resort_data|
			resort_data.each do |season_day, season_data|
				existing_day = $data_map[resort_name]['average'][season_day]
				if existing_day
					existing_day.update_attributes(
						base: season_data.to_f / averages_denom_map[resort_name][season_day]
					)
				else
					new_day = SnowDay.create(
						resort_name: resort_name,
						resort_id: resort_id,
						base: season_data.to_f / averages_denom_map[resort_name][season_day],
						season_day: season_day,
						generated: true,
						season_name: 'Average'
					)
					# p 'created average snow day'
				end
			end
		end
	end
	p 'done building season data'
	p 'writing data map'
	return_and_write_data_map
end




# field :resort_name, :type => String
# field :resort_id, :type => String
# field :date, :type => Date
# field :base, :type => Integer
# field :date_string, :type => Integer
# field :precipitation, :type => Integer
# field :season_snow, :type => Integer
# field :season_day, :type => Integer
# field :season_start_year, :type => Integer
# field :season_end_year, :type => Integer
# field :season_name, :type => String
# field :generated, :type => Boolean, :default => false