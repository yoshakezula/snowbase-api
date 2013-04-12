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
			days.each do |day|
				cols = day.css('td')
				date = Date.parse cols[0].text

				#Start season in November and end in april, also skip for feb 29
				next if (date.month < 11 && date.month > 4) || (date.month == 2 && date.day == 29)
				date_string = date.year * 10000 + date.month * 100 + date.day

				date_string = date_string.to_s

				resort_id = Resort.where(:resort_name => resort_name).first_or_create._id

				existing_day = SnowDay.where(:resort_name => resort_name, :date_string => date_string).first

				if !existing_day
					p 'Creating snow day for ' + resort_name + ': ' + date_string
					new_day = SnowDay.create(
						resort_name: resort_name,
						date_string: date_string,
						date: date,
						resort_id: resort_id,
						base: cols[3].text.match(/[0-9]+/)[0].to_i,
						precipitation: cols[1].text.match(/[0-9]+/)[0].to_i,
						season_snow: cols[3].text.match(/[0-9]+/)[0].to_i
					)
				else
					if $skipExistingDays
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
							season_snow: cols[3].text.match(/[0-9]+/)[0].to_i
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