require 'bundler/setup'
require 'sinatra'
require 'json'
require 'mongo'
require 'uri'
require './scraper'
require './data-processor'

if !development?
  p 'production'
  ENV['MONGOID_ENV'] = 'production'
  def get_connection
    return @db_connection if @db_connection
    db = URI.parse(ENV['MONGOHQ_URL'])
    db_name = db.path.gsub(/^\//, '')
    @db_connection = Mongo::Connection.new(db.host, db.port).db(db_name)
    @db_connection.authenticate(db.user, db.password) unless (db.user.nil? || db.user.nil?)
    @db_connection
  end
  db = get_connection
end

if development?
  p 'development'
  require './development'
  require "sinatra/reloader"
  require 'aws/s3'
end

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

class Resort
  include Mongoid::Document

  field :name, :type => String
  field :state, :type => String
  field :formatted_name, :type => String
end

def write_data_maps(snow_day_map)
  timestamp = Time.new.to_s.gsub(/[\s\-\:]/, "")[0..11]

  AWS::S3::Base.establish_connection!(
    :access_key_id => ENV['AWS_ACCESS_KEY_ID'],
    :secret_access_key => ENV['AWS_SECRET_ACCESS_KEY']
  )

  # open existing snow_day_map and write old version to s3
  old_snow_day_map = open('https://snowbase-api.s3.amazonaws.com/snow_day_map.json').read.to_json
  AWS::S3::S3Object.store(
    'snow_day_map_' + timestamp + '.json',
    old_snow_day_map.to_json,
    ENV['AWS_BUCKET'],
    :access => :public_read
  )

  # write new snow_day_map
  p 'wrote https://snowbase-api.s3.amazonaws.com/snow_day_map_' + timestamp + '.json'
  AWS::S3::S3Object.store(
    'snow_day_map.json',
    snow_day_map.to_json,
    ENV['AWS_BUCKET'],
    :access => :public_read
  )
  p 'wrote https://snowbase-api.s3.amazonaws.com/snow_day_map.json'

  # open existing resort_map and write old version to s3
  old_resort_map = open('https://snowbase-api.s3.amazonaws.com/resort_map.json').read.to_json
  new_resort_map = Resort.all.to_json
  if old_resort_map != new_resort_map
    AWS::S3::S3Object.store(
      'resort_map_' + timestamp + '.json',
      old_resort_map.to_json,
      ENV['AWS_BUCKET'],
      :access => :public_read
    )
    p 'wrote https://snowbase-api.s3.amazonaws.com/resort_map_' + timestamp + '.json'

    #Write new resort map
    AWS::S3::S3Object.store(
      'resort_map.json',
      new_resort_map,
      ENV['AWS_BUCKET'],
      :access => :public_read
    )
    p 'wrote https://snowbase-api.s3.amazonaws.com/resort_map.json'
    redirect to '/resorts'
  end
end

get '/delete-resort/:id' do
  content_type :json
  resort = Resort.where(_id: params[:id]).first
  if resort
    resort.destroy
    redirect to '/delete-snow-days-for/' + params[:id]
  else
    'couldn\'t find resort'
  end
end

get '/pull/all' do
  content_type :json
  Resort.all.each do |resort|
    pullDataFor(resort)
  end
  SnowDay.all.to_json
end

post '/update-resort' do
  resort = Resort.find(params[:id])
  resort.update_attributes(
    name: params[:name],
    formatted_name: params[:formatted_name],
    state: params[:state]
  )
  redirect to '/resorts'
end

get '/pull/:state/:name' do
  content_type :json
  resort = Resort.where(name: params[:name], state: params[:state]).first_or_create
  pullDataFor(resort)
  redirect to '/api/snow-days/' + resort.name
end

get '/add/:state/:name' do
  resort = Resort.where(name: params[:name], state: params[:state]).first_or_create
  redirect to '/resort/' + resort.name
end

get '/api/resorts' do
  content_type :json
  Resort.all.to_json
end

get '/resorts' do
  @resorts = Resort.all
  erb :resorts
end

get '/resort/:name' do
  @resort = Resort.where(name: params[:name]).first
  erb :resort
end

get '/scraper-log' do
  f = File.open('logs/scraper_log.txt', "r")
  f.read
end

get '/data-processor-log' do
  f = File.open('logs/data_processor_log.txt', "r")
  f.read
end

get '/api/snow-days' do
  content_type :json
  query = params[:resort_id] ? SnowDay.where(:resort_id => params[:resort_id]) : SnowDay.all
  query.to_json
end

get '/api/snow-days/:resort_name' do
  content_type :json
  SnowDay.where(:resort_name => params[:resort_name]).to_json
end

get '/delete-generated-snow-days' do
  content_type :json
  #destroy previously-generatd snowdays
  SnowDay.where(:generated => true).destroy_all
  SnowDay.all.to_json
end

get '/delete-snow-days-for/:resort_id' do
  content_type :json
  SnowDay.where(:resort_id => params[:resort_id]).destroy_all
  'deleted'
end

get '/write-data-maps' do
  write_data_maps(return_and_write_data_maps)
end

get '/build-season-data' do
  #Pass results of build_season_data to write_data_maps
  write_data_maps(build_season_data)
end