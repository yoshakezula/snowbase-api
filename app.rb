require 'bundler/setup'
require 'sinatra'
require 'json'
require 'mongo'
require 'uri'
require './resort'
require './snow-day'
require './scraper'
require './data-processor'

if !development?
  p 'production'
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
  SnowDay.all.to_json
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

get '/api/snow-days-map' do
  content_type :json
  dir = Dir.open 'json'
  f = File.open('json/' + dir.max, "r")
  f.read
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
  # normalize_data[params[:resort_name]].to_json
  SnowDay.find(params[:_id]).to_json
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

get '/build-season-data' do
  content_type :json
  data_map = build_season_data
  AWS::S3::Base.establish_connection!(
    :access_key_id => ENV['AWS_ACCESS_KEY_ID'],
    :secret_access_key => ENV['AWS_SECRET_ACCESS_KEY']
  )
  AWS::S3::S3Object.store(
    'data_map.json',
    data_map.to_json,
    ENV['AWS_BUCKET'],
    :access => :public_read
  )
  p 'wrote https://snowbase-api.s3.amazonaws.com/data_map.json'
  SnowDay.all.to_json
end