var myServices;
var myServicesColorAndDescription={};
var myCMDBs;

var d=new Date();
var now=Math.floor(d.getTime()/1000);
var maxHoursDifference=6;

function validateCMDBConfigAndSave() {
  console.log('check params and save cmdb');
  $('#addCMDBmodal').modal('hide');
  var editedCMDB={};
  editedCMDB['display_name']=$('#display_name').val();
  editedCMDB['description']=$('#description').val();
  editedCMDB['cmdb_endpoint']=$('#cmdb_endpoint').val();
  editedCMDB['cmdb_username']=$('#cmdb_username').val();
  editedCMDB['cmdb_password']=$('#cmdb_password').val();
  editedCMDB['tags']=$('#tags').val();
  editedCMDB['active']=$('#active').val();
  // console.log(editedCMDB);
  $.post('/api/v1/cmdb/'+encodeURIComponent($('#display_name').val())+'.json', JSON.stringify(editedCMDB))
  .fail(function() {
    alertThis('Error saving CMDB.','danger');
  })
  .done(function(result){
    if (result.description!=='') {
      alertThis('CMDB saved ('+result.description+')','warning');
    }
  });
  // on save:
  // get relevant data (accounts/static KPI) via API and cache it in mongo...
  // refresh table
  updateCMDBList();
}

function checkEndpoint() {
  console.log('password entered, check endpoint access and get description');
}

function editCMDB(index) {
  console.log('edit CMDB');
  // fill fields
    $('#display_name').val(myCMDBs[index].display_name);
    $('#cmdb_endpoint').val(myCMDBs[index].cmdb_endpoint);
    $('#cmdb_username').val(myCMDBs[index].cmdb_username);
    $('#cmdb_password').val(myCMDBs[index].cmdb_password);
    $('#description').val(myCMDBs[index].description);
    $('#tags').val(myCMDBs[index].tags);
    $('#active').val(myCMDBs[index].active);
  // show modal
  $('#addCMDBmodal').modal('show');
}

function updateCMDBList() {
  spinThatWheel(true);
  $.getJSON('/api/v1/cmdb.json', function( cmdb ) {
    if (cmdb) {
      myCMDBs=cmdb;
      $("#cmdbtable > tbody").html("");
      for (var i=0; i<cmdb.length; i++) {
        // spaces as a separator, "," in mongodb
        var tags='';
        var vdc_name;
        // console.log(cmdb[i]._id.$oid); // mongo OID for this vdc entry
        if (cmdb[i].tags) {
          var atags=cmdb[i].tags.split(',');
          for (var j=0; j<atags.length; j++) {
            tags+='<span class="label label-info">'+atags[j]+'</span>&nbsp;';
          }
        } else { tags='No tags defined'; }
        if (!cmdb[i].description) { cmdb[i].description='N/A'; }
        if (cmdb[i].display_name) { vdc_name=cmdb[i].display_name.replace(/ /g,'_'); }
        $('#cmdbtable tbody').append('<tr><td><h4>'+((cmdb[i].active) ? '<span class="label label-success">Yes</span>' : '<span class="label label-danger">No</span>')+'</h4></td><td><strong>'+cmdb[i].display_name+'</strong></td><td width=15%>'+cmdb[i].description+'</td><td>'+tags+'</td><td style="text-align:center"><a class="btn btn-xs btn-primary" data-toggle="tooltip" title="Edit" onclick="editCMDB(\''+i+'\');"><i class="fa fa-pencil"></i></a></td><td width=5%><a class="btn btn-xs btn-danger" data-toggle="tooltip" title="Remove" onclick="removeCMDB(\''+cmdb[i]._id.$oid+'\');"><i class="fa fa-trash"></i></a></td></tr>');
      }
      $('#cmdbcount').text(cmdb.length);
    } else {
      $("#cmdb > tbody").html("");
      $('#cmdbcount').text(0);
      alertThis('No CMDB found. Try adding an active one!','danger');
    }
    spinThatWheel(false);
  });
}

function updateServiceList() {
  $("#servicestable > tbody").html("");
  for (var service in myServices) {
    if (typeof myServicesColorAndDescription[service] == 'undefined') {
      myServicesColorAndDescription[service]={
        description: 'No description available.',
        color: stringToColor(service)
      };
    }
    $('#servicestable > tbody').append('<tr><td><strong>'+service+'</strong></td><td width=55%><input id="'+service+'_description" type="text" class="form-control" value="'+myServicesColorAndDescription[service].description+'"></td><td><input id='+service+'_color" value="'+myServicesColorAndDescription[service].color+'" type="color" /></td></tr>');
  }
  $('#servicescount').text(Object.keys(myServices).length);
}

function initPage() {
  console.log( "initPage called" );
  // Enable tooltips
  $("body").tooltip({ selector: '[title]' });

  $('#addCMDB').click(function() {
    $('#display_name').val('');
    $('#cmdb_endpoint').val('');
    $('#cmdb_username').val('');
    $('#cmdb_password').val('');
    $('#description').val('');
    $('#tags').val('');
    $('#active').val('');
    $('#addCMDBmodal').modal('show');
  });

  $('#cmdb_password').on('click', checkEndpoint);
  $('#saveCMDB').on('click', validateCMDBConfigAndSave);

  // check localstorage for myServices and myServices.date
  if (Modernizr.localstorage && localStorage["myServices.date"] > (now - 60*60*maxHoursDifference)) {
    // save data is still fresh (not older than X hours)
    if (localStorage.getItem('myServices')) {myServices = JSON.parse(localStorage.getItem('myServices'));}
    if (localStorage.getItem('myServicesColorAndDescription')) {myServicesColorAndDescription = JSON.parse(localStorage.getItem('myServicesColorAndDescription'));}
  } else {
    console.log('stale services, refresh from backend');
    // get services from backend
    $.getJSON('/api/v1/gethostsperservice.json', function( services ) {
      if (services) {
        // it's an obj/hash with a single service as key
        myServices=services;
        // save locally myServices
          if (Modernizr.localstorage && localStorage["exasteel"] === "lives") {
          // window.localStorage is available!
          localStorage["myServices"] = JSON.stringify(myServices);
          localStorage["myServices.date"] = now;
        }
      } else {
        $("#services > tbody").html("");
        $('#servicescount').text(0);
        alertThis('No Services found. Check CMDB source or try adding one!','danger');
      }
      spinThatWheel(false);
    });
  }

  // when changing service description OR color save it! (bind on tbale because rith now there are no rows!)
  $('#servicestable').change(function(e){
    // TODO change method of detecting which service property has changed
    arr=$(e.target).attr('id').split("_");
    console.log(arr);
    var service=arr[0];  // service name
    var property=arr[1]; // description or color
    myServicesColorAndDescription[service][property]=$(e.target).val();
    console.log('service '+property+' changed for '+service+', value: '+$(e.target).val());
    if (Modernizr.localstorage && localStorage["exasteel"] === "lives") {
      localStorage["myServicesColorAndDescription"] = JSON.stringify(myServicesColorAndDescription);
    }
    $("#saved").fadeIn(750);
    $("#saved").fadeOut(1750);
  });

  // fill tables
  updateCMDBList();
  updateServiceList();
}

function refreshPage() {
  console.log( "refreshPage called" );
}