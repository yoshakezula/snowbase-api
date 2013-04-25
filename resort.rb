require 'mongo'
require 'mongoid'
# Mongoid.load!('mongoid.yml')

class Resort
  include Mongoid::Document

  field :name, :type => String
  field :state, :type => String
  field :formatted_name, :type => String
  field :state_short, :type => String
  field :state_formatted, :type => String
end