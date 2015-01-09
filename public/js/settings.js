
function validateConfigAndSave() {
  console.log('check params and save emoc');
  $('#addvDCmodal').modal('hide');
}

function checkEndpoint() {
  console.log('password entered, check endpoint access and get description');
}

function initPage() {
  console.log( "initPage called" );
  // Enable tooltips
  $(function () {
    $('[data-toggle="tooltip"]').tooltip();
  });
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

  $('#addvDC').click(function() {
    $('#addvDCmodal').modal('show');
  });

  $('#password').on('click', checkEndpoint);

  $('#savevDC').on('click', validateConfigAndSave);

  $('#theme').click(function() {
    mySessionData['theme']=$(this).text();
    setSessionData();
  });
}

function refreshPage() {
  console.log( "refreshPage called" );
}