require 'rubygems'
require 'bundler'
Bundler.require(:default)
require 'sinatra'
require './app'

set :root, Pathname(__FILE__).dirname
set :environment, :production

run Sinatra::Application