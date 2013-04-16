require 'nokogiri'
require 'open-uri'
require 'json'
require './snow-day'
require './data-processor'
require 'debugger'
$skipExistingDays = false

def pullDataFor(resort)
	log = Logger.new('logs/scraper_log.txt')
	log.level = Logger::WARN
	log.error('Start parse')

	years = ['2007', '2008', '2009', '2010', '2011', '2012', '2013']
	resort_name = resort.name
	years.each do |year|
		uri = 'http://www.onthesnow.com/' + resort.state + '/' + resort_name + '/historical-snowfall.html?&y=' + year + '&q=base&v=list#view'
		p 'opening nokogiri for ' + uri
		log.error 'opening nokogiri for ' + uri
		begin
			doc = Nokogiri::HTML(open(uri))

			#check for formatted resort name
			if !resort.formatted_name
				if doc.css('.resort_name').length > 0
					resort.update_attributes(formatted_name: doc.css('.resort_name')[0].text)
				else
					resort.update_attributes(formatted_name: resort.name)
				end
				p 'populating formatted report name: ' + resort.formatted_name
				log.error 'populating formatted report name: ' + resort.formatted_name
			end

			days = doc.css('table.snowfall tr:not(.titleRow)')
			days.each do |day|
				# log.error day.inspect
				cols = day.css('td')
				date = Date.parse cols[0].text

				#Start season in November and end in april, also skip for feb 29
				next if (date.month < 11 && date.month > 4) || (date.month == 2 && date.day == 29)
				date_string = date.year * 10000 + date.month * 100 + date.day

				date_string = date_string.to_s

				resort_id = Resort.where(:name => resort_name).first._id

				base = cols[3].text.match(/[0-9]+/)[0].to_i

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
					log.error 'new day created'
					log.error new_day.inspect
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
						log.error 'existing day updated'
						log.error existing_day.inspect
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