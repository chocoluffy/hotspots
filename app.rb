require 'sinatra'
require 'sinatra/content_for'
require 'sass'
require 'json'
require 'net/http'
require 'algorithms'

require File.dirname(__FILE__) + '/lib/quadtree'
require File.dirname(__FILE__) + '/lib/vector'

GEONAMES_URL = "http://ws.geonames.net/findNearbyPostalCodesJSON"
GEONAMES_USERNAME = "ms_test201302"

WEATHERBUG_URL = "http://i.wxbug.net/REST/Direct/GetForecast.ashx"
WEATHERBUG_APIKEY = "rpjv5wkg9q465bkuzrhdrqbg"

R = 6373 # earths radius

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
			puts res.body
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

		zips = cities.join(",")
		params[:zip] = zips
		uri.query = URI.encode_www_form(params)
		res = Net::HTTP.get_response(uri)
		if res.is_a?(Net::HTTPSuccess)
			return JSON.parse(res.body)
		else 
			puts res.body
			return res.body
		end
	end

end

get '/' do
	erb :index
end

post '/getweather' do 

	content_type :json
	postal_codes = get_postal_codes(params[:lat], params[:lng]) # query geonames

	if postal_codes.empty? or postal_codes.nil?
		{ :error => "Oops! That is not a valid city. Please try again." }.to_json
	else
		# Create a quad tree
		qt = QuadTree.new(Vector.new(-180,90), Vector.new(180,-90))

		# sort the postal codes result by name
		postal_codes.sort! {|a,b| a['placeName'].downcase <=> b['placeName'].downcase}
		previous = postal_codes[0]['placeName']

		postal_codes.each do |item|
			# skip if the name is empty or if it is the same name as the previous entry
			next if item['placeName'].empty? or previous == item['placeName']

			lat = item['lat'].to_f
			lng = item['lng'].to_f
			details =  { 
				:name => item['placeName'], 
				:postalcode => item['postalCode'].to_i, 
				:state => item['adminCode1'], 
				:distance => item['distance'],
				:lat => item['lat'].to_f,
				:lng => item['lng'].to_f
			}

			# 0.045 is equal to 5km, assuming that 1 deg = 111.111 km (naive implementation, I know)
			# this code creates a 10km by 10km square around the current lat, lng. We will query the 
			# quad tree to see if there are any points that already lie in this region.
			offset = 0.045
			payloads = qt.payloads_in_region(
				Vector.new(lng - offset, lat + offset), Vector.new(lng + offset, lat - offset))

			if payloads.length > 0
				# add the current item to the first payload
				payloads[0].data.push(details)
			else
				# add new payload
				qt.add(QuadTreePayload.new(Vector.new(lng, lat), [details]))
			end
			previous = item['placeName']
		end

		# cities are now grouped by points in the Quad tree. Now create a hash based on the first 
		# postal code of a city at a point. This is easier for querying weatherbug.
		pcodes_hash = Hash[qt.get_contained[:payloads].map{ |x| [x.data[0][:postalcode], x.data] }]
		ordered_pcodes = pcodes_hash.keys
		weather = get_weather(ordered_pcodes) # query weatherbug

		weather_heap = Containers::MinHeap.new # create a min heap

		if weather.is_a?(Array)
			weather.each_with_index do |item, index|
				if forecast = item['forecastList'][0]
					key = 	if forecast['high'].nil?
								forecast['low']
							else
								forecast['high']
							end
					# add the element if the heap size is less than 10 or if the temperature is 
					# higher than the smallest temperature in the heap
					if weather_heap.size < 10 or weather_heap.min[:key] < key.to_i

						# remove the heap min if it is smaller than the current temp
						weather_heap.pop if weather_heap.size >= 10 and weather_heap.min[:key] < key.to_i

						# remove relevant info from weatherbug
						if forecast['hasDay']
							desc = forecast['dayDesc']
							pred = forecast['dayPred']
							icon = forecast['dayIcon']
						else
							desc = forecast['nightDesc']
							pred = forecast['nightPred']
							icon = forecast['nightIcon']
						end
						pcode = ordered_pcodes[index]
						pcodes_hash[pcode].each do |p|
							if weather_heap.size < 10
								weather_heap.push(key.to_i, {
									:key => key.to_i,
									:city => p,
									:high => forecast['high'],
									:low => forecast['low'],
									:desc => desc,
									:pred => pred,
									:icon => icon,
									:day => forecast['dayTitle']
								})
							end
						end
					end
				end
			end

			sorted_weather = []

			# extract each min from the heap to get the sorted order
			while not weather_heap.empty?
				sorted_weather.unshift(weather_heap.pop)
			end
			{ :results => sorted_weather }.to_json
		else
			{ :error => "Oops! The query can handle only so many cities :(" }.to_json
		end
	end
end