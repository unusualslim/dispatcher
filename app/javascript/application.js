// Entry point for the build script in your package.json
//= require bootstrap-sprockets
//= require rails-ujs
//= require select2

import "@hotwired/turbo-rails"
import "./controllers"
import "trix"
import "@rails/actiontext"

$(document).ready(function() {
  $('#location_search').select2({
    placeholder: 'Search for a location',
    ajax: {
      url: '/locations/search',
      dataType: 'json',
      delay: 250,
      data: function(params) {
        return {
          query: params.term // search term
        };
      },
      processResults: function(data) {
        return {
          results: data.map(function(location) {
            return {
              id: location.id,
              text: location.city_with_company // adjust this according to how you want it displayed
            };
          })
        };
      },
      cache: true
    }
  });

  // Set the hidden field with the selected location's ID
  $('#location_search').on('select2:select', function(e) {
    var data = e.params.data;
    $('#location_id').val(data.id); // Set the hidden field
  });
});
