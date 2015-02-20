var myServices;
var myCMDBs;

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

function validateServiceConfigAndSave() {
  console.log('Validate CMDB config and save');
}

function checkEndpoint() {
  console.log('password entered, check endpoint access and get description');
}

function removeServices(id) {
  console.log('removeServices '+id+' from list AND db (via DELETE API)');
  // TODO are you sure????
  $.ajax({
    url: '/api/v1/vdc/'+encodeURIComponent(id)+'.json',
    type: 'DELETE',
    success: function(result) {
      alertThis('Deleted successfully','success');
    },
    error: function(jqXHR, textStatus, errorThrown ) {
      alertThis('Error deleting: '+errorThrown,'danger');
    }
  });
  updateServiceList();
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

function editServices(srv) {
  console.log('edit Services');
  // fill fields
    $('#display_name').val(myServices[srv].display_name);
    $('#description').val(myServices[srv].description);
  // show modal
  $('#addServicemodal').modal('show');
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
  spinThatWheel(true);
  $.getJSON('/api/v1/gethostsperservice.json', function( services ) {
    if (services) {
      // it's an obj/hash with a single service as key
      myServices=services;
      $("#servicestable > tbody").html("");
      for (var service in services) {
        var service_name;
        if (!services[service].description) { services[service].description='No description available'; }
        // if (services[service].display_name) { service_name=services[service].display_name.replace(/ /g,'_'); }
        $('#servicestable tbody').append('<tr><td><strong>'+service+'</strong></td><td width=15%>'+services[service].description+'</td><td><div style="background-color:'+stringToColour(service)+';width:150px;"></div></td><td style="text-align:center"><a class="btn btn-xs btn-primary" data-toggle="tooltip" title="Edit" onclick="editServices(\''+service+'\');"><i class="fa fa-pencil"></i></a></td></tr>');
      }
      $('#servicescount').text(Object.keys(services).length);
      // save locally myServices
        if (Modernizr.localstorage && localStorage["exasteel"] === "lives") {
        // window.localStorage is available!
        localStorage["myServices"] = JSON.stringify(myServices);
        var d=new Date();
        localStorage["myServices.date"] = Math.round(d.getTime()/1000);
      }
    } else {
      $("#services > tbody").html("");
      $('#servicescount').text(0);
      alertThis('No Services found. Check CMDB source or try adding one!','danger');
    }
    spinThatWheel(false);
  });
}

function initPage() {
  console.log( "initPage called" );
  // Enable tooltips
  $("body").tooltip({ selector: '[title]' });
  // $( "#settings_container .form-control" ).change(function() {
  //   console.log("form changed: "+$(this).attr('id')+" = "+ $(this).val());
  //   switch($(this).attr('id')) {
  //     case 'units': mySessionData['units']=$(this).val();
  //                   break;
  //     case 'theme': mySessionData['theme']=$(this).val();
  //                   break;
  //     default: break;
  //   }
  //   // quick feedback to the user: settings accepted!
  //     $("#saved").fadeIn(750);
  //     $("#saved").fadeOut(1750);
  //   setSessionData();
  // });

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

  $('#addService').click(function() {
    $('#display_name').val('');
    $('#emoc_endpoint').val('');
    $('#emoc_username').val('');
    $('#emoc_password').val('');
    $('#ovmm_endpoint').val('');
    $('#ovmm_username').val('');
    $('#ovmm_password').val('');
    $('#description').val('');
    $('#tags').val('');
    $('#ignored_accounts').val('');
    $('#addServicemodal').modal('show');
  });

  $('#cmdb_password').on('click', checkEndpoint);

  $('#saveCMDB').on('click', validateCMDBConfigAndSave);

  $('#saveService').on('click', validateServiceConfigAndSave);

  // fill tables
  updateCMDBList();
  updateServiceList();
}

function refreshPage() {
  console.log( "refreshPage called" );
}