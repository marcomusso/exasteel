var MyVDCS={};

function fillKPI(element) {
  var gaugeOptions={
    width       : 150,
    height      : 150,
    glow        : false,
    units       : '#',
    minValue    : 0,
    maxValue    : 128,
    majorTicks  : [0,8,16,32,64,128],
    minorTicks  : 2,
    strokeTicks : false
  };
  console.log('fillKPI called on '+element);
  var w = $('#'+element).width();
  var h = 100;
  // DEMO GRAPH
    // var dataset = [
    //         {
    //           x: 5,
    //           y: 20,
    //           r: 10,
    //           c: "black"
    //         },
    //         {
    //           x: 480,
    //           y: 90,
    //           r: 20,
    //           c: "#43f5e5"
    //         },
    //         {
    //           x: 250,
    //           y: 50,
    //           r: 15,
    //           c: "magenta"
    //         },
    //         {
    //           x: 100,
    //           y: 33,
    //           r: 7,
    //           c: "green"
    //         },
    //         {
    //           x: 330,
    //           y: 95,
    //           r: 18,
    //           c: "yellow"
    //         },
    //         {
    //           x: 410,
    //           y: 12,
    //           r: 19,
    //           c: "red"
    //         },
    //         {
    //           x: 475,
    //           y: 44,
    //           r: 25,
    //           c: "gray"
    //         },
    //         {
    //           x: 25,
    //           y: 67,
    //           r: 12,
    //           c: "blue"
    //         },
    //         {
    //           x: 85,
    //           y: 21,
    //           r: 5,
    //           c: "darkblue"
    //         },
    //         {
    //           x: 220,
    //           y: 88,
    //           r: 3,
    //           c: "orange"
    //         }
    //         ];
    // var xScale = d3.scale.linear()
    //            .domain([0, d3.max(dataset, function(d) { return d.x; })])
    //            .range([0, w]);
    // var yScale = d3.scale.linear()
    //            .domain([0, d3.max(dataset, function(d) { return d.y; })])
    //            .range([0, h]);
    // var svg = d3.select(element)
    //     .append("svg")
    //     .attr("width", "100%")
    //     .attr("height", h);
    // svg.selectAll("circle")
    //   .data(dataset)
    //   .enter()
    //   .append("circle")
    //   .attr("cx", w / 2)
    //   .attr("cy", h / 2)
    //   .attr("r", 1)
    //   // explode from the middle
    //   .transition()
    //   .duration(2000)
    //   .attr("cx", function(d) {
    //     return xScale(d.x);
    //   })
    //   .attr("r", function(d) {
    //     return d.r*2;
    //   })
    //   .attr("cy", function(d) {
    //     return yScale(d.y);
    //   })
    //   .attr("fill", function(d) {
    //    return d.c;
    //   })
    //   // center x in the middle
    //   .transition()
    //   .duration(1000)
    //   .attr("cx", function(d) {
    //     return w/2;
    //   })
    //   // all the way down in the middle, zoome 5x
    //   .transition()
    //   .duration(2000)
    //   .attr("cy", function(d) {
    //     return h;
    //   })
    //   .attr("r", function(d) {
    //     return d.r*5;
    //   })
    //   // zoom 3x and go to the original coordinates
    //   .transition()
    //   .duration(1000)
    //   .attr("cx", function(d) {
    //   return xScale(d.x);
    //   })
    //   .attr("r", function(d) {
    //    return d.r*3;
    //   })
    //   .attr("cy", function(d) {
    //    return yScale(d.y);
    //   });

  // GAUGES
  $('#'+element).append('<div class="col-xs-1 col-sm-1 col-md-1 col-lg-1"></div>');
  // $('#'+element).append('<div class="col-xs-2 col-sm-2 col-md-2 col-lg-2"><canvas id="'+element+'_vServersRunning"></canvas></div>');
  $('#'+element).append('<div class="col-xs-2 col-sm-2 col-md-2 col-lg-2"><div id="'+element+'_vServersRunning"></div></div>');
  // $('#'+element).append('<div class="col-xs-2 col-sm-2 col-md-2 col-lg-2"><canvas id="'+element+'_vCPUAllocated"></canvas></div>');
  $('#'+element).append('<div class="col-xs-2 col-sm-2 col-md-2 col-lg-2"><div id="'+element+'_vCPUAllocated"></div></div>');
  // $('#'+element).append('<div class="col-xs-2 col-sm-2 col-md-2 col-lg-2"><canvas id="'+element+'_vStorageAllocated"></canvas></div>');
  $('#'+element).append('<div class="col-xs-2 col-sm-2 col-md-2 col-lg-2"><div id="'+element+'_vStorageAllocated"></div></div>');
  // $('#'+element).append('<div class="col-xs-2 col-sm-2 col-md-2 col-lg-2"><canvas id="'+element+'_vMemoryAllocated"></canvas></div>');
  $('#'+element).append('<div class="col-xs-2 col-sm-2 col-md-2 col-lg-2"><div id="'+element+'_vMemoryAllocated"></div></div>');
  // $('#'+element).append('<div class="col-xs-2 col-sm-2 col-md-2 col-lg-2"><canvas id="'+element+'_Networks"></canvas></div>');
  $('#'+element).append('<div class="col-xs-2 col-sm-2 col-md-2 col-lg-2"><div id="'+element+'_Networks"></div></div>');
  $('#'+element).append('<div class="col-xs-1 col-sm-1 col-md-1 col-lg-1"></div>');

  // vServersRunning
    // gaugeOptions.renderTo=element+'_vServersRunning';
    // gaugeOptions.title='vServersRunning';
    // var vServersRunning_gauge = new Gauge(gaugeOptions);
    // vServersRunning_gauge.onready = function() {
    //     vServersRunning_gauge.setValue(4);
    // }; vServersRunning_gauge.draw();
  // vCPUAllocated
    // gaugeOptions.renderTo=element+'_vCPUAllocated';
    // gaugeOptions.title='vCPUAllocated';
    // var vCPUAllocated_gauge = new Gauge(gaugeOptions);
    // vCPUAllocated_gauge.onready = function() {
    //     vCPUAllocated_gauge.setValue(31);
    // }; vCPUAllocated_gauge.draw();
  // vStorageAllocated
    // gaugeOptions.renderTo=element+'_vStorageAllocated';
    // gaugeOptions.title='vStorageAllocated';
    // var vStorageAllocated_gauge = new Gauge(gaugeOptions);
    // vStorageAllocated_gauge.onready = function() {
    //     vStorageAllocated_gauge.setValue(31);
    // }; vStorageAllocated_gauge.draw();
  // vMemoryAllocated
    // gaugeOptions.renderTo=element+'_vMemoryAllocated';
    // gaugeOptions.title='vMemoryAllocated';
    // var vMemoryAllocated_gauge = new Gauge(gaugeOptions);
    // vMemoryAllocated_gauge.onready = function() {
    //     vMemoryAllocated_gauge.setValue(31);
    // }; vMemoryAllocated_gauge.draw();
  // Networks
    // gaugeOptions.renderTo=element+'_Networks';
    // gaugeOptions.title='Networks';
    // var Networks_gauge = new Gauge(gaugeOptions);
    // Networks_gauge.onready = function() {
    //     Networks_gauge.setValue(4);
    // }; Networks_gauge.draw();

  var vServersRunning = new JustGage({
                              id: element+'_vServersRunning',
                              value: Math.floor(Math.random() * 128) + 1,
                              min: 0,
                              max: 128,
                              title: "# of vServers Running",
                              showMinMax: true,
                              levelColorsGradient: true,
                              gaugeWidthScale: 0.5,
                              showInnerShadow: true,
                              startAnimationType: "bounce",
                                levelColors: [
                                  "#770000",
                                  "#aa0000",
                                  "#ff0000"
                                ]
                              });
  var vStorageAllocated = new JustGage({
                              id: element+'_vStorageAllocated',
                              value: Math.floor(Math.random() * 1024) + 1,
                              min: 0,
                              max: 1024,
                              title: "Allocated Storage (GB)",
                              showMinMax: true,
                              levelColorsGradient: true,
                              gaugeWidthScale: 0.5,
                              showInnerShadow: true,
                              startAnimationType: "bounce",
                                levelColors: [
                                  "#770000",
                                  "#aa0000",
                                  "#ff0000"
                                ]
                              });
  var vMemoryAllocated = new JustGage({
                              id: element+'_vMemoryAllocated',
                              value: Math.floor(Math.random() * 1024) + 1,
                              min: 0,
                              max: 1024,
                              title: "Allocated Memory (GB)",
                              showMinMax: true,
                              levelColorsGradient: true,
                              gaugeWidthScale: 0.5,
                              showInnerShadow: true,
                              startAnimationType: "bounce",
                                levelColors: [
                                  "#770000",
                                  "#aa0000",
                                  "#ff0000"
                                ]
                              });
  var vCPUAllocated = new JustGage({
                              id: element+'_vCPUAllocated',
                              value: Math.floor(Math.random() * 32) + 1,
                              min: 0,
                              max: 32,
                              title: "# of allocated vCPU",
                              showMinMax: true,
                              levelColorsGradient: true,
                              gaugeWidthScale: 0.5,
                              showInnerShadow: true,
                              startAnimationType: "bounce",
                                levelColors: [
                                  "#770000",
                                  "#aa0000",
                                  "#ff0000"
                                ]
                              });
  var Networks = new JustGage({
                              id: element+'_Networks',
                              value: Math.floor(Math.random() * 32) + 1,
                              min: 0,
                              max: 32,
                              title: "# Network IFs",
                              showMinMax: true,
                              levelColorsGradient: true,
                              gaugeWidthScale: 0.5,
                              showInnerShadow: true,
                              startAnimationType: "bounce",
                                levelColors: [
                                  "#770000",
                                  "#aa0000",
                                  "#ff0000"
                                ]
                              });

  // <VDC_display_name>_EL01_vServersRunning gauge vServersRunning / vServersTotal
  // <VDC_display_name>_vCPUAllocated        gauge vCPUAllocated/vCPUQuota
  // <VDC_display_name>_vStorageAllocated    gauge vStorageAllocated/vStorageQuota
  // <VDC_display_name>_vMemoryAllocated     gauge vMemoryAllocated/vMemoryQuota
  // <VDC_display_name>_Networks             counter Network (low pri)

}

function initPage() {
  console.log( "initPage called" );
  // Enable tooltips
  $("body").tooltip({ selector: '[title]' });

  $.getJSON('/api/v1/getvdcs.json', function( vdcs ) {
    if (vdcs) {
      MyVDCS=vdcs;
      var select = document.getElementById("vdc");
      for (i=0; i<MyVDCS.length; i++) {
        select.options[select.options.length] = new Option(MyVDCS[i].display_name+' - '+MyVDCS[i].asset_description, MyVDCS[i].display_name);
      }
      // save to local storage (http://stackoverflow.com/questions/2010892/storing-objects-in-html5-localstorage)
        // Put the object into storage
        localStorage.setItem('MyVDCS', JSON.stringify(MyVDCS));
        // Retrieve the object from storage
        var retrievedObject = localStorage.getItem('MyVDCS');
        console.log('retrievedObject: ', JSON.parse(retrievedObject));
    // update server pool FOR FIRST VDC
      // TODO - mocked
      $('#vdc_server_pools tbody').append('<tr><td>el01Pool1</td><td>128</td><td>2</td><td>256</td><td>1024</td><td>4</td></tr>');
    // display tags FOR FIRST VDC
      var tags=MyVDCS[0].tags.split(',');
      for (t = 0; t < tags.length; t++) {
        $('#tags').append('<span class="label label-info">'+tags[t]+'</span>&nbsp;');
      }
    // display accounts KPI  FOR FIRST VDC
      selectedVDC=MyVDCS[0].display_name;
      // (TODO sanitize display_name)
      $.getJSON('/api/v1/vdcaccounts/'+selectedVDC+'.json', function( accounts ) {
        if (accounts['status']==="ERROR") {
          alertThis('Something went wrong when asking for accounts for VDC '+selectedVDC,'danger');
        } else {
          // draw panels from template
          var template=$(".panel-template");
          for (var account in accounts ) {
            // add panel for account only for NOT ignored accounts
            if (!MyVDCS[0].ignored_accounts.match(account)) {
              // clone template
              var newPanel=template.clone();
              newPanel.find(".panel-title").attr("id", account).text(account+' ('+accounts[account].description+')');
              newPanel.find(".kpi").attr("id", account+'_kpi');
              newPanel.removeClass('hidden');
              $('#accountsContainer').append(newPanel.fadeIn());
              fillKPI(account+'_kpi');
            }
          }
        }
      });
    }
   });

  // if another vdc get selected...
  $('#vdc').change(function() {
    refreshPage();
  });
}

function refreshPage() {
  console.log( "refreshPage called" );

  $('#accountsContainer').html('');
  $('#tags').html('');
  $('#vdc_server_pools > tbody').html('');

  var selectedVDC=$('#vdc').val();

  // update server pool
    // TODO - mocked
    $('#vdc_server_pools tbody').append('<tr><td>el01Pool1</td><td>128</td><td>2</td><td>256</td><td>1024</td><td>4</td></tr>');
  // display tags
    for (v=0; v<MyVDCS.length; v++) {
      if (MyVDCS[v].display_name===selectedVDC) {
        var tags=MyVDCS[v].tags.split(',');
        for (t = 0; t < tags.length; t++) {
          $('#tags').append('<span class="label label-info">'+tags[t]+'</span>&nbsp;');
        }
      }
    }
  // display accounts
    $.getJSON('/api/v1/vdcaccounts/'+selectedVDC+'.json', function( accounts ) {
      if (accounts['status']==="ERROR") {
        alertThis('Something went wrong when asking for accounts for VDC '+selectedVDC,'danger');
      } else {
        // draw panels from template
        var template=$(".panel-template");
        for (var account in accounts ) {
          // add panel for account only for NOT ignored accounts
          if (true) {
            // clone template
            var newPanel=template.clone();
            var title;
            if (accounts[account].description) {
              title=account+' ('+accounts[account].description+')';
            } else {
              title=account;
            }
            newPanel.find(".panel-title").attr("id", account).text(title);
            newPanel.find(".kpi").attr("id", account+'_kpi');
            newPanel.removeClass('hidden');
            $('#accountsContainer').append(newPanel.fadeIn());
            fillKPI(account+'_kpi');
          }
        }
      }
    });
}
