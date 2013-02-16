require "rubygems"
require "bundler"
require 'sass/plugin/rack'

Bundler.require

Sass::Plugin.options[:template_location] = 'public/stylesheets'
use Sass::Plugin::Rack

require "./app"
run Sinatra::Application