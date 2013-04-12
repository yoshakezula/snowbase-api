require "bundler/setup"
require 'sinatra'
require "sinatra/reloader" if development?
require 'json'
require 'mongo'
require 'uri'
require './resort'
require './snow-day'
require './scraper'
require './data-processor'

if !development?
  def get_connection
    return @db_connection if @db_connection
    db = URI.parse(ENV['MONGOHQ_URL'])
    db_name = db.path.gsub(/^\//, '')
    @db_connection = Mongo::Connection.new(db.host, db.port).db(db_name)
    @db_connection.authenticate(db.user, db.password) unless (db.user.nil? || db.user.nil?)
    @db_connection
  end

  db = get_connection
  
  set :server, 'thin'

  use Rack::CommonLogger

  log = File.new("logs/sinatra.log", "a+")
  log.sync = true
  STDOUT.reopen(log)
  STDERR.reopen(log)
end

get '/add-resort/:name' do
  content_type :json
  resort = Resort.where(name: params[:name]).first_or_create
  resort.to_json
end

get '/delete-resort/:name' do
  content_type :json
  resort = Resort.where(name: params[:name]).first
  if resort
    resort.destroy
  end
  'deleted'
end

get '/pull/:name' do
  content_type :json
  resort = Resort.where(name: params[:name]).first_or_create
  pullDataFor(resort)
  SnowDay.all.to_json
end

get '/resorts' do
  content_type :json
  headers 'Access-Control-Allow-Origin' => 'http://localhost:3000'
  Resort.all.to_json
end

get '/snow-days' do
  content_type :json
  headers 'Access-Control-Allow-Origin' => 'http://localhost:3000'
  normalize_data.to_json
  # SnowDay.all.to_json
end

get '/delete-snow-days' do
  content_type :json
  SnowDay.destroy_all
  SnowDay.all.to_json
end

get '/build-season-data' do
  content_type :json
  build_season_data
  SnowDay.all.to_json
end

get '/snow-days/:resort_name' do
  content_type :json
  headers 'Access-Control-Allow-Origin' => 'http://localhost:3000'
  normalize_data[params[:resort_name]].to_json
  # SnowDay.where(resort_name: params[:resort_name]).all.to_json
end