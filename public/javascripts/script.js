
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
    	console.log(data);
      console.log(data.length);
    }
  }); // end ajax

}

function displayWeather(postalcodes){
	var p = {"items": postalcodes.splice(0,10)};
	p.items = $.map(p.items, function(item) {
		var query = item.name + "+" + item.state;
		item.maps = "https://maps.google.com/?q=" + query.replace(" ", "+");
		item.wiki = "http://en.wikipedia.org/wiki/Special:Search/" + item.name.replace(" ", "_");
		return item;
	});

	console.log(p);
var html = Mustache.to_html(Templates.weatherDesc, p);
$(".results-content").append(html);
$("#results-container").fadeIn("slow");
}

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
});