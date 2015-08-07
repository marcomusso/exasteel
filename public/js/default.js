var mySessionData={};

// if you want to lookup real hostname from Exalogic name attribute use this variable and
// the corresponding function lookupHostname(name,direction)
  var lookupHostnameFlag=true;

// string to color (http://stackoverflow.com/questions/3426404/create-a-hexadecimal-colour-based-on-a-string-with-javascript)
var stringToColor = function(str) {
    var hash = 0;
    for (var i = 0; i < str.length; i++) {
        hash = str.charCodeAt(i) + ((hash << 5) - hash);
    }
    var colour = '#';
    for (var i = 0; i < 3; i++) {
        var value = (hash >> (i * 8)) & 0xFF;
        colour += ('00' + value.toString(16)).substr(-2);
    }
    return colour;
}
// For pages with automatic refresh
  var countdownfrom = 30; //countdown period in seconds
  var currentsecond=countdownfrom+1;
  var counterobj = document.getElementById("counter");
  if (counterobj) {counterobj.innerHTML = countdownfrom+1; }
  function countdown() {
      if (currentsecond!=1) {
          currentsecond-=1;
          if (counterobj) { counterobj.innerHTML = currentsecond; }
      } else {
          refreshPage();
          return;
      }
      setTimeout(countdown,1000);
  }
// let's round a number
  function round(num,decimals) {
      return Math.round(num * Math.pow(10, decimals)) / Math.pow(10, decimals);
  }
// Return an Object sorted by it's Key
  function sortObjectByKey(obj) {
    var keys = [];
    var sorted_obj = {};

    for(var key in obj){
        if(obj.hasOwnProperty(key)){
            keys.push(key);
        }
    }

    // sort keys
    keys.sort();

    // create new array based on Sorted Keys
    jQuery.each(keys, function(i, key){
        sorted_obj[key] = obj[key];
    });

    return sorted_obj;
  }
// unique values in array
  function uniqueArray(a) {
      return a.reduce(function(p, c) {
          if (p.indexOf(c) < 0) p.push(c);
          return p;
      }, []);
  }
// smart binary units
  function byte2human(size, mode) {
    // mode puo' essere SI (base 10) o IEC (base 2)
    var base = 1024;
    var suffixes = ['B','KiB','MiB','GiB','TiB'];
    // base puo' essere 1000 (MB,GB...) o 1024 (MiB,GiB....)
    if (mode == 'SI') {
      base = 1000;
      suffixes = ['B','KB','MB','GB','TB'];
    }
    var suffix_idx = 0;
    while (Math.abs(size) > (0.8*base)) {
      size /= base;
      suffix_idx += 1;
      // oltre i terabyte non si puo' andare
      if (suffix_idx >= suffixes.length) { break; }
    }
    return size.toFixed(1)+' '+suffixes[suffix_idx];
  }
// loading feedback
  function spinThatWheel(state) {
    // state: true/false
    if (state) {
      $("#loading").addClass('fa-spin');
      $("#loading").show();
    } else {
      $("#loading").removeClass('fa-spin');
      $("#loading").hide();
    }
  }
// Enable/Disable refresh indicator
  function refreshIndicator(state) {
    $(".refresh_indicator").toggleClass('invisible');
    if (state) { counterobj = document.getElementById("counter"); }
  }
// themes
  var themes = {
    "default"  : "/bootstrap-3.2.0/css/bootstrap-theme.css",
    "cosmo"    : "/css/bootstrap-themes/bootstrap-cosmo.min.css",
    "flatly"   : "/css/bootstrap-themes/bootstrap-flatly.min.css",
    "slate"    : "/css/bootstrap-themes/bootstrap-slate.min.css",
    "spacelab" : "/css/bootstrap-themes/bootstrap-spacelab.min.css",
    "yeti"     : "/css/bootstrap-themes/bootstrap-yeti.min.css"
  };

  // $(function(){
  //   var themesheet = $('<link href="'+themes[mySessionData['theme']]+'" rel="stylesheet" />');
  //   var exasteelsheet = $('<link href="/css/exasteel.css" rel="stylesheet" />');
  //   themesheet.appendTo('head');
  //   exasteelsheet.appendTo('head');
  //   $('.theme-link').click(function(){
  //      var themeurl = themes[$(this).attr('data-theme')];
  //       themesheet.attr('href',themeurl);
  //   });
  // });
// set session in cookie
  function setSessionData() {
    console.log( "setSessionData called" );
    $.post( "/api/setsession.json",
      JSON.stringify(mySessionData)
    ).fail(function() {
      alert( "Error saving session, please contact support." );
    });
  }
// talk to the user! TODO: add time parameter
  function alertThis(message,severity,icon) {
    if (icon === undefined) {
      icon='fa fa-warning';
    }
    if (severity === undefined) {
      icon='info';
    }
    if (message === undefined) {
      console.log('alertThis called without message!');
      return false;
    }
    $.growl({
      message: message,
      icon: icon
    },{
      element: 'body',
      allow_dismiss: true,
      placement: {
        from: "top",
        align: "center"
      },
      offset: 20,
      spacing: 10,
      animate: {
        enter: 'animated fadeInLeftBig',
        exit: 'animated fadeOutRightBig'
      },
      type: severity,
      delay: 3000,
      template: '<div data-growl="container" class="alert" role="alert">' +
                    '<button type="button" class="close" data-growl="dismiss">' +
                      '<span aria-hidden="true">×</span>' +
                      '<span class="sr-only">Close</span>' +
                    '</button>' +
                    '<span data-growl="icon"></span>&nbsp;' +
                    '<span data-growl="title"></span>' +
                    '<span data-growl="message"></span>' +
                    '<a href="#" data-growl="url"></a>' +
                 '</div>'
    });
  }
$("document").ready(function() {
  spinThatWheel(false);
  refreshIndicator(false);
  $("#saved").fadeOut(0);
  // let's get session data and call initPage()
    $.getJSON( "/api/getsession.json", function( data ) {
      $.each( data, function( key, val ) {
        mySessionData[key]=val;
        // console.log("getSessionData: "+key+' = '+val);
        for (key in mySessionData) {
          switch(key) {
            case 'units': if ($('#units').length) { $("#units").val(mySessionData[key]); }
                          break;
            case 'theme': if ($('#theme').length) { $("#theme").val(mySessionData[key]); }
                         break;
            default: break;
          }
        }
     });
    }).done(function() {
      if (Modernizr.localstorage) {
        // window.localStorage is available!
        localStorage["exasteel"] = "lives";
      } else {
        // no native support for HTML5 storage :(
        // maybe try dojox.storage or a third-party solution
        if (document.URL.indexOf("/no-local-storage") === -1) {
          window.location.replace("/no-local-storage");
        }
      }
      // Enable tooltips with HTML enabled
        $(document.body).tooltip({ selector: "[title]", html: true });
      initPage();
    });
});
