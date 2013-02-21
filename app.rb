require 'sinatra'
require 'sinatra/content_for'
require 'sass'
require 'json'
require 'net/http'
require 'set'

GEONAMES_URL = "http://ws.geonames.net/findNearbyPostalCodesJSON"
GEONAMES_USERNAME = "ms_test201302"

WEATHERBUG_URL = "http://i.wxbug.net/REST/Direct/GetForecast.ashx"
WEATHERBUG_APIKEY = "rpjv5wkg9q465bkuzrhdrqbg"

helpers do 
	def get_postal_codes(lat, lng)
		# 30 miles = ~48 km
		radius = 48
		params = { 
			:lat => lat, 
			:lng => lng, 
			:radius => radius,
			:maxRows => 1000,
			:style => "FULL",
			:country => "US",
			:username => GEONAMES_USERNAME
		}
		uri = URI(GEONAMES_URL)

		uri.query = URI.encode_www_form(params)
		res = Net::HTTP.get_response(uri)
		if res.is_a?(Net::HTTPSuccess)
			return JSON.parse(res.body)['postalCodes']
		else 
			return {}
		end
	end

	def get_weather(cities)
		params = {
			:nf => 1,
			:l => "en",
			:api_key => WEATHERBUG_APIKEY
		}

		uri = URI(WEATHERBUG_URL)

		results = []

		# make 1 call for every 50 postal codes
		if cities.length > 50 
			index = 0
			while index <= cities.length
				index += 50
				start = if index - 50 <= 0 then 0 else index - 49 end
				section = cities[start..index]
				zips = section.map{ |x| x[:postalcode] }.join(",")
				params[:zip] = zips
				uri.query = URI.encode_www_form(params)
				res = Net::HTTP.get_response(uri)
				if res.is_a?(Net::HTTPSuccess)
					JSON.parse(res.body).each do |item|
						weather = {}
						
					end
				end
			end
		else 
			zips = cities.map{ |x| x[:postalcode] }.join(",")
			params[:zip] = zips
			uri.query = URI.encode_www_form(params)
			res = Net::HTTP.get_response(uri)
			if res.is_a?(Net::HTTPSuccess)
				results = JSON.parse(res.body).zip(cities)
			end
		end

		return results
	end
end

get '/' do
	erb :index
end

post '/getweather' do 
	content_type :json
	postal_codes = get_postal_codes(params[:lat], params[:lng])
	if postal_codes.empty? or postal_codes.nil?
		{ :error => "Oops! That is not a valid city. Please try again." }.to_json
	else
		cities = []
		# nlgn
		postal_codes.sort! { |a,b| a['placeName'].downcase <=> b['placeName'].downcase }
		previous = postal_codes[0]['placeName']
		# n
		postal_codes.each do |item|
			next if item['placeName'].empty? or item['placeName'] == previous
			cities.push({ :name => item['placeName'], 
				:postalcode => item['postalCode'], 
				:state => item['adminCode1'], 
				:distance => item['distance']})
			previous = item['placeName']
		end

		weather = get_weather(cities)

		weather[0..3].to_json
	end
end