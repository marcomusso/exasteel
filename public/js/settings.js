var MyVDCS;

function validateConfigAndSave() {
  console.log('check params and save emoc');
  $('#addvDCmodal').modal('hide');
  var editedVDC={};
  editedVDC['display_name']=$('#display_name').val();
  editedVDC['asset_description']=$('#asset_description').val();
  editedVDC['emoc_endpoint']=$('#emoc_endpoint').val();
  editedVDC['emoc_username']=$('#emoc_username').val();
  editedVDC['emoc_password']=$('#emoc_password').val();
  editedVDC['ovmm_endpoint']=$('#ovmm_endpoint').val();
  editedVDC['ovmm_username']=$('#ovmm_username').val();
  editedVDC['ovmm_password']=$('#ovmm_password').val();
  editedVDC['tags']=$('#tags').val();
  editedVDC['ignored_accounts']=$('#ignored_accounts').val();
  var sanitizedName=$('#display_name').val().replace(/ /g,'_'); // TODO use proper url encoding
  // console.log(editedVDC);
  $.post('/api/v1/vdc/'+sanitizedName+'.json', JSON.stringify(editedVDC))
  .fail(function() {
    alertThis('Error saving VDC.','danger');
  })
  .done(function(result){
    if (result.description!=='') {
      alertThis('VDC saved ('+result.description+')','warning');
    }
  });
  // on save:
  // get relevant data (accounts/static KPI) via API and cache it in mongo...
  // refresh table
  updatevDCList();
}

function checkEndpoint() {
  console.log('password entered, check endpoint access and get description');
}

function removevDCs(id) {
  console.log('removevDCs '+id+' from list AND db (via DELETE API)');
  // TODO are you sure????
  $.ajax({
    url: '/api/v1/vdc/'+id+'.json',
    type: 'DELETE',
    success: function(result) {
      alertThis('Deleted successfully','success');
    },
    error: function(jqXHR, textStatus, errorThrown ) {
      alertThis('Error deleting: '+errorThrown,'danger');
    }
  });
  updatevDCList();
}

function editvDCs(index) {
  console.log('edit vDCs');
  // fill fields
    $('#display_name').val(MyVDCS[index].display_name);
    $('#emoc_endpoint').val(MyVDCS[index].emoc_endpoint);
    $('#emoc_username').val(MyVDCS[index].emoc_username);
    $('#emoc_password').val(MyVDCS[index].emoc_password);
    $('#ovmm_endpoint').val(MyVDCS[index].ovmm_endpoint);
    $('#ovmm_username').val(MyVDCS[index].ovmm_username);
    $('#ovmm_password').val(MyVDCS[index].ovmm_password);
    $('#asset_description').val(MyVDCS[index].asset_description);
    $('#tags').val(MyVDCS[index].tags);
    $('#ignored_accounts').val(MyVDCS[index].ignored_accounts);
  // show modal
  $('#addvDCmodal').modal('show');
}

function updatevDCList() {
  spinThatWheel(true);
  $.getJSON('/api/v1/getvdcs.json', function( vdcs ) {
    if (vdcs) {
      MyVDCS=vdcs;
      $("#vdcstable > tbody").html("");
      for (var i=0; i<vdcs.length; i++) {
        // spaces as a separator, "," in mongodb
        var tags='';
        var vdc_name;
        // console.log(vdcs[i]._id.$oid); // mongo OID for this vdc entry
        if (vdcs[i].tags) {
          var atags=vdcs[i].tags.split(',');
          for (var j=0; j<atags.length; j++) {
            tags+='<span class="label label-info">'+atags[j]+'</span>&nbsp;';
          }
        } else { tags='No tags defined'; }
        if (!vdcs[i].asset_description) { vdcs[i].asset_description='N/A'; }
        if (vdcs[i].display_name) { vdc_name=vdcs[i].display_name.replace(/ /g,'_'); }
        $('#vdcstable tbody').append('<tr><td><strong><a href="/vdc/'+vdc_name+'">'+vdcs[i].display_name+'</a></strong></td><td width=15%>'+vdcs[i].asset_description+'</td><td>'+vdcs[i].emoc_endpoint+'</td><td>'+vdcs[i].ovmm_endpoint+'</td><td>'+tags+'</span></td><td style="text-align:center"><a class="btn btn-xs btn-primary" data-toggle="tooltip" title="Edit" onclick="editvDCs(\''+i+'\');"><i class="fa fa-pencil"></i></a></td><td width=5%><a class="btn btn-xs btn-danger" data-toggle="tooltip" title="Remove" onclick="removevDCs(\''+vdcs[i]._id.$oid+'\');"><i class="fa fa-trash"></i></a></td></tr>');
      }
      $('#vdcscount').text(vdcs.length);
    } else {
      $("#vdcs > tbody").html("");
      $('#vdcscount').text(0);
      alertThis('No vDCs found. Try adding one!','danger');
    }
    spinThatWheel(false);
  });
}

function initPage() {
  console.log( "initPage called" );
  // Enable tooltips
  $("body").tooltip({ selector: '[title]' });
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
    $('#display_name').val('');
    $('#emoc_endpoint').val('');
    $('#emoc_username').val('');
    $('#emoc_password').val('');
    $('#ovmm_endpoint').val('');
    $('#ovmm_username').val('');
    $('#ovmm_password').val('');
    $('#asset_description').val('');
    $('#tags').val('');
    $('#ignored_accounts').val('');
    $('#addvDCmodal').modal('show');
  });

  $('#emoc_password').on('click', checkEndpoint);

  $('#savevDC').on('click', validateConfigAndSave);

  // fill vdcstable
  updatevDCList();
}

function refreshPage() {
  console.log( "refreshPage called" );
}