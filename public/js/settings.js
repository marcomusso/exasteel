function initPage() {
  console.log( "initPage called" );
  $( "#settings_container .form-control" ).change(function() {
    console.log("form changed: "+$(this).attr('id')+" = "+ $(this).val());
    switch($(this).attr('id')) {
      case 'unita': mySessionData['units']=$(this).val();
                    break;
      case 'theme': mySessionData['theme']=$(this).val();
                   break;
      default: break;
    }
    // quick feedback to the user: settings accepted!
      $("#saved").fadeIn(750);
      $("#saved").fadeOut(1750);
    setSessionData();
  });

  $(".dropdown-menu li a").click(function () {
    // console.log("Selected Option:"+$(this).text());
    mySessionData['theme']=$(this).text();
    setSessionData();
  });
}

function refreshPage() {
  console.log( "refreshPage called" );
}