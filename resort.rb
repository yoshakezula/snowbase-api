require 'mongo'
require 'mongoid'

ENV['MONGOID_ENV'] = 'development'

Mongoid.load!('mongoid.yml')

class Resort
	include Mongoid::Document

	field :name, :type => String
	field :state, :type => String
end