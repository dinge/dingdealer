document.observe("dom:loaded", function() {

  document.observe("mouse_event:out", function(event) {
    var container = $(Event.element(event.memo)).up('.tools_phrase_maker_triple');
    if(container != undefined ) {
      var control = container.down('.control');
      if(control != undefined) {
        control.hide();
      }
    }
  });

  document.observe("mouse_event:over", function(event) {
    var container = $(Event.element(event.memo)).up('.tools_phrase_maker_triple');
    if(container != undefined ) {
      var control = container.down('.control');
      if(control != undefined) {
        control.show();
      }
    }
  });



  document.observe("mouse_event:out", function(event) {
    var container = $(Event.element(event.memo)).up('.tools_phrase_maker_triple .control');
    if(container != undefined ) {
      container.up('.tools_phrase_maker_triple .wrapper').removeClassName('active');
    }
  });

  document.observe("mouse_event:over", function(event) {
    var container = $(Event.element(event.memo)).up('.tools_phrase_maker_triple .control');
    if(container != undefined ) {
      container.up('.tools_phrase_maker_triple .wrapper').addClassName('active');
    }
  });

});