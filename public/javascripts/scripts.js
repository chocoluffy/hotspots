
// Namespaces;
var Templates = {} ;

function getPostalCodes(data, spinner) {
	spinner.spin();
	$("#results-spinner").append(spinner.el);

 	$.ajax({
    url: "/getweather",
    method: "POST",
    dataType: "json",
    data: data,
    success: function( data ) {
      console.log("hello");
    	if (data.error) {
        alert(data.error);
      } else {
        spinner.stop();
        results = data.results;
        displayWeather(data.results);
      }
    }
  }); // end ajax

}

function displayWeather(weathers){
  $(".results-content").empty();
	var p = {}
	p.items = $.map(weathers, function(item) {
		var query = item.city.name + "+" + item.city.state;
		item.maps = "https://maps.google.com/?q=" + query.replace(" ", "+");
		item.wiki = "http://en.wikipedia.org/wiki/Special:Search/" + item.city.name.replace(" ", "_");
		return item;
	});
  var html = Mustache.to_html(Templates.weatherDesc, p);
  $(".results-content").append(html);
  $("#results-container").fadeIn("slow");
}

var curr_sort = "high";
var curr_order = "desc";
var results = [];

$(function() {

  Templates.weatherDesc = $("#weather-description").html();

  var target = document.getElementById("city-spinner");
  var spinner = new Spinner({
    lines: 11,
    length: 3,
    width: 2, 
    radius: 4,
    corners: 1,
    className: 'spinner',
    zIndex: 2e9, 
    top: 15,
    left: 180
  }).spin();

  var results_spinner = new Spinner({
    lines: 13,
    length: 11,
    width: 4,
    radius: 14, 
    className: 'spinner', 
    zIndex: 2e9,
    top: 'auto', 
    left: 'auto'
  });

  $( "#city" ).autocomplete({
    source: function( request, response ) {
      $.ajax({
        url: "http://ws.geonames.net/searchJSON",
        dataType: "jsonp",
        data: {
          featureClass: "P",
          style: "full",
          maxRows: 10,
          name_startsWith: request.term,
          country: "US",
          username: "ms_test201302"
        },
        beforeSend: function(jqxhr, settings) {
        	spinner.spin(target);
        	$(".results-content").empty();
        	$("#results-container").fadeOut("fast");
        },
        success: function( data ) {
        	spinner.stop();
          response( $.map( data.geonames, function( item ) {
            return {
              label: item.name + (item.adminName1 ? ", " + item.adminName1 : ""),
              value: item.name,
              lat: item.lat,
              lng: item.lng
            }
          }));
        }
      });
    },
    minLength: 2,
    select: function( event, ui ) {
    	getPostalCodes(ui.item, results_spinner);
    }
  });


  // Sorting
  $("#sort-by").change(function() {
    var val = $(this).find(":selected").val();
    if(val != curr_sort && results) {
      curr_sort = val;
      // resort the results
      if(val === "high") {
        results.sort(function(a,b){
          return a.high - b.high;
        });
      } else if (val == "low") {
        results.sort(function(a,b){
          return a.low - b.low;
        });
      } else if (val == "distance") {
        results.sort(function(a,b){
          return a.city.distance - b.city.distance;
        });
      }
      if (curr_order == "desc") results.reverse();
      displayWeather(results);
    }
  });

  // ordering
  $("#order-by").change(function() {
    var val = $(this).find(":selected").val();
    if(val != curr_order && results) {
      curr_order = val;
      results.reverse();
      displayWeather(results);
    }
  });


});