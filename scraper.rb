require 'nokogiri'
require 'open-uri'
require 'json'
require './snow-day'
require './data-processor'
require 'debugger'
$skipExistingDays = false

def pullDataFor(resort)
	years = ['2007', '2008', '2009', '2010', '2011', '2012', '2013']
	resort_name = resort.name
	years.each do |year|
		uri = 'http://www.onthesnow.com/colorado/' + resort_name + '/historical-snowfall.html?&y=' + year + '&q=base&v=list#view'
		p 'opening nokogiri for ' + uri
		begin
			doc = Nokogiri::HTML(open(uri))
			days = doc.css('table.snowfall tr:not(.titleRow)')
			# previous_base = nil
			# previous_month = 1
			days.each do |day|
				cols = day.css('td')
				date = Date.parse cols[0].text

				#Start season in November and end in april, also skip for feb 29
				next if (date.month < 11 && date.month > 4) || (date.month == 2 && date.day == 29)
				date_string = date.year * 10000 + date.month * 100 + date.day

				date_string = date_string.to_s

				resort_id = Resort.where(:name => resort_name).first_or_create._id

				base = cols[3].text.match(/[0-9]+/)[0].to_i

				# #if we've skipped ahead more than 2 months, then reset the previous_base var
				# if date.month - previous_month > 2
				# 	previous_base = nil
				# 	p 'resetting previous_base because entering the next season'
				# end
				# previous_month = date.month

				# #Skip day if the data is way off
				# if previous_base && ((base.to_f / previous_base.to_f) - 1).abs > 0.3
				# 	p 'skipping ' + date_string + ' because data is crap. ' + 'previous day: ' + previous_base.to_s + '. this base: ' + base.to_s
				# 	next
				# end
				# #set the previous_base var to today
				# previous_base = base

				existing_day = SnowDay.where(:resort_name => resort_name, :date_string => date_string).first

				if !existing_day
					p 'Creating snow day for ' + resort_name + ': ' + date_string
					new_day = SnowDay.create(
						resort_name: resort_name,
						date_string: date_string,
						date: date,
						resort_id: resort_id,
						base: base,
						precipitation: cols[1].text.match(/[0-9]+/)[0].to_i,
						season_snow: cols[3].text.match(/[0-9]+/)[0].to_i
					)
				else
					if $skipExistingDays && (date.year != Time.now.year) #never skip if the date is this year, because we always want to update for most recent year. But we can ignore past years
						p 'Existing snow day found for ' + resort_name + ': ' + date_string + ', skipping'
					else
						p 'Updating snow day for ' + resort_name + ': ' + date_string
						existing_day.update_attributes(
							resort_name: resort_name,
							date_string: date_string,
							date: date,
							resort_id: resort_id,
							base: cols[3].text.match(/[0-9]+/)[0].to_i,
							precipitation: cols[1].text.match(/[0-9]+/)[0].to_i,
							season_snow: cols[3].text.match(/[0-9]+/)[0].to_i,
							generated: false
						)
					end
				end
			end
		rescue Exception => e
			p 'error with ' + uri
			p e
		end
	end	
	normalize_data()
end