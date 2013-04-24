require 'mongo'
require 'mongoid'

Mongoid.load!('mongoid.yml')

class SnowDay
	include Mongoid::Document

	field :resort_name, :type => String
	field :resort_id, :type => String
	field :date, :type => Date
	field :base, :type => Integer
	field :date_string, :type => Integer
	field :precipitation, :type => Integer
	field :season_snow, :type => Integer
	field :season_day, :type => Integer
	field :season_start_year, :type => Integer
	field :season_end_year, :type => Integer
	field :season_name, :type => String
	field :generated, :type => Boolean, :default => false

	index({ resort_name: 1 }, { name: "resort_name_index" })
	
end