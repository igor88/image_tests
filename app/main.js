// Filename: main.js

// Require.js allows us to configure mappings to paths
// as demonstrated below:

var dir = "../js/lib/";


require.config({

//  baseUrl: "../js/lib/",

  paths: {
//    twitterBootstrap: dir + 'bootstrap.min',
    jquery                  : dir + 'jquery/jquery',
    underscore              : dir + 'underscore/underscore',
    backbone                : dir + 'backbone/backbone',
    Raphael                 : dir + 'raphael-eve/raphael',
    RaphaelFreeTransform    : dir + 'raphael-free-transform/raphael.free_transform',
    jqueryForm              : dir + 'jquery-form/jquery.form',
    text                    : dir + 'requirejs-text/text',
    cs                      : dir + 'require-cs/cs',
    benchmark               : dir + 'benchmark-js/benchmark',
    jasmine                 : dir + 'jasmine/lib/jasmine-core/jasmine'
  },

  shim: {

    jquery: {
      exports: '$'
    },

    underscore: {
      exports: '_'
    },

    backbone: {
      deps: ['underscore', 'jquery'],
      exports: 'Backbone'
    },

    jQueryForm: {
      deps: ['jquery']
    },

    Raphael: {
      exports: 'Raphael'
    },

    RaphaelFreeTransform: {
      deps: ['Raphael'],
      exports: 'Raphael'
    }

//    twitterBootstrap: {
//      deps: ["jquery"]
//    },

  }

});



require(['backbone', 'cs!app'], function(Backbone, App){
  console.log('REQUIRE')
  window.app = new App;
  Backbone.history.start({
//    pushState: true,
    root: location.pathname
  });
});

