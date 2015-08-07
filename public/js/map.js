var myVDCS;
var myServices;
var myServicesColorAndDescription;

var d=new Date();
var now=Math.floor(d.getTime()/1000);
// var maxHoursDifference=0.2; // TTL for localStorage data, disabled for the time being

var margins = {
  top: 10,
  bottom: 10,
  left: 10,
  right: 10
};
var i=0, duration, tree, diagonal;
var width, height, w, h;
var link, node, root, force, vis;
var barHeight, barWidth, duration;
var rx, ry, m0, rotate = 0;
var cluster, nodes;
var svg;

// refresh timers
  var refreshInterval = countdownfrom*1000; // global default page refresh, milliseconds!!! see default.js
  var refreshTimer;
  var counterTimer;

function lookupHostname(name,direction) {
  if (lookupHostnameFlag) {
    // implement your rule here, example:
    switch (direction) {
      case 'name2hostname': return name;
                            break;
      case 'hostname2name': var number=name.match(/(.)(\d+)$/);
                            return 'sapvx'+number[1]+number[2];
                            break;
      default: return name;
    }
  } else {
    // no difference between names and hostnames
    return name;
  }
}

function getCurrentSite() {
  // return site of currently selected vdc: $('#vdc').val()
  var tags; // array
  var site='unknown'; // if there isn't a site:xxxx tag defined then site is unknown
  if (myVDCS) {
    for (i=0; i<myVDCS.length; i++) {
      if (myVDCS[i].display_name===$('#vdc').val()) { tags=myVDCS[i].tags.split(","); }
    }
    var patt = new RegExp(/site\:([a-z]*)/g);
    for (i=0; i<tags.length; i++) {
      if (patt.test(tags[i])) { site=tags[i].match(/site\:([a-z]*)/g)[0].split(":")[1]; }
    }
  }
  return site;
}

function getCurrentEnv() {
  // return env of currently selected vdc: $('#vdc').val()
  var tags; // array
  var env;
  var aEnv=[];
  if (myVDCS) {
    for (i=0; i<myVDCS.length; i++) {
      if (myVDCS[i].display_name===$('#vdc').val()) { tags=myVDCS[i].tags.split(","); }
    }
    var patt = new RegExp(/env\:([a-z]*)/g);
    // TODO add different env to this array and then flatten it joining its elemtes with ","
    for (i=0; i<tags.length; i++) {
      if (patt.test(tags[i])) {
        aEnv[aEnv.length]=tags[i].match(/env\:([a-z]*)/g)[0].split(":")[1];
      }
    }
  }
  // default env=prod if no tag env: defined (especially on page first load)
  if (aEnv.length>0) { env=aEnv.join(","); } else { env='prod'; }
  return env;
}

function getExalogicControlStatus(d) {
  arr=d.name.split(':');
  return (arr[1]==='1') ? "lime" : "red";
}

function updateSwitches() {
  $('#switches > tbody').html('');
  myServices=sortObjectByKey(myServices);
  for (var service in myServices) {
    var myservers=myServices[service]['listenHosts'].sort().join('<br>');
    $('#switches > tbody').append('<tr><td data-toggle="tooltip" data-placement="left" title="'+myservers+'"><input type="checkbox" class="myswitches" data-toggle="toggle" data-onstyle="success" data-offstyle="danger" id="'+service+'" data-size="small" data-on="'+service+' ON" data-off="'+service+' OFF"></td></tr>');
  }
  // enable bootstraptoogle
  $('.myswitches').bootstrapToggle();
  $('.myswitches').change(function() {
    // console.log(myServices[$(this).attr('id')].listenHosts);
    var hostname,status,arr;
    if ($(this).prop('checked')) {
      for (idx = 0; idx < myServices[$(this).attr('id')].listenHosts.length; idx++) {
        // highlight ONLY the hostnames which are in this site
        // split hostname from status
        arr=myServices[$(this).attr('id')].listenHosts[idx].split(':');
        hostname=arr[0];
        status=arr[1];
        // we should consider only hostname matching current site or "nc" (Domain servers)
        if (hostname.indexOf(getCurrentSite())!=-1 || hostname.indexOf('nc')!=-1) {
          // console.log('Hightlight ON for '+lookupHostname(hostname,'hostname2name')+' ['+hostname+','+status+','+((status!=='0') ? 'green' : 'red')+']');
          $('.service_'+lookupHostname(hostname,'hostname2name')).attr("fill",myServicesColorAndDescription[$(this).attr('id')].color);
          $('.service_'+lookupHostname(hostname,'hostname2name')).attr("opacity","0.8");
          // the circle color represents the status of the guest: red==inactive, green==active
          $('.status_'+lookupHostname(hostname,'hostname2name')).attr("fill", ((status!=='0') ? 'lime' : 'red'));
        }
        // else {
          // console.log('ignored '+hostname);
        // }
      }
    } else {
      for (idx = 0; idx < myServices[$(this).attr('id')].listenHosts.length; idx++) {
        // split hostname from status
        arr=myServices[$(this).attr('id')].listenHosts[idx].split(':');
        hostname=arr[0];
        // console.log('Hightlight OFF for '+lookupHostname(hostname,'hostname2name'));
        $('.service_'+lookupHostname(hostname,'hostname2name')).attr("opacity","0");
        $('.status_'+lookupHostname(hostname,'hostname2name')).attr("fill","lightblue");
      }
    }
  });
}

function initPage() {
  console.log("initPage called");
  if ($('#visualization').length) { $("#visualization").val(mySessionData['mapvisualization']); }
  $.getJSON('/api/v1/getvdcs.json', function( vdcs ) {
    if (vdcs) {
      myVDCS=vdcs;
      var select = document.getElementById("vdc");
      for (i=0; i<myVDCS.length; i++) {
        // console.log(myVDCS[i].display_name);
        select.options[select.options.length] = new Option(myVDCS[i].display_name+' - '+myVDCS[i].asset_description, myVDCS[i].display_name);
      }
      // display tags FOR FIRST VDC
        var tags=myVDCS[0].tags.split(',');
        for (t = 0; t < tags.length; t++) {
          $('#tags').append('<span class="label label-info">'+tags[t]+'</span>&nbsp;');
        }
      drawGraph();
    }
  }).fail(function(){
    alertThis('Error in getting VDC list','danger');
  });
  // if another vdc get selected...
  $('#vdc').change(function() {
    $('.myswitches').bootstrapToggle('off');
    refreshPage();
  });
  // if the user wants to change the visualization
  $('#visualization').change(function() {
    mySessionData['mapvisualization']=$("#visualization").val();
    setSessionData();
    refreshPage();
  });
  // get services from backend, for a specific environment as defined in the "env:" tag
  $.getJSON('/api/v1/gethostsperservice/'+getCurrentEnv()+'.json', function( services ) {
    if (services) {
      // it's an obj/hash with a single service as key
      myServices=services;
      // save locally myServices
      if (Modernizr.localstorage) {
        myServices=sortObjectByKey(myServices);
        localStorage["myServices"] = JSON.stringify(myServices);
      }
      if (localStorage.getItem("myServicesColorAndDescription")===null) {
        alertThis('Unable to load color labels! Please go to Admin->Settings->Services to define color mapping.','warning');
      } else {
        myServicesColorAndDescription = JSON.parse(localStorage.getItem('myServicesColorAndDescription'));
      }
      updateSwitches();
    } else {
      alertThis('No Services found. Check CMDB source or try adding one!','danger');
    }
    spinThatWheel(false);
  });
  $('#autorefresh-switch').change(function() {
    // console.log('Toggle '+$(this).attr('id')+' to '+$(this).prop('checked'));
    if ($(this).prop('checked')) {
      console.log('Enabled autorefresh every '+refreshInterval/1000+' secs.');
      refreshIndicator(true);
      counterTimer=setTimeout(countdown,1000);
    } else {
      console.log('Disabled autorefresh.');
      window.clearTimeout(counterTimer);
      refreshIndicator(false);
    }
  });
}

function drawGraph() {
  $('#map').html('');
  width=$('#map').width();    // before margins
  height=$('#map').height();  // before margins
  w=width - margins.right - margins.left;   // after margins
  h=height - margins.top - margins.bottom;  // after margins

  svg = d3.select("#map").append("svg:svg")
      .attr("width", w)
      .attr("height", h);

  switch($('#visualization').val()) {
    case 'domain': tree = d3.layout.tree()
                       .size([height, width]);
                   diagonal = d3.svg.diagonal()
                       .projection(function(d) { return [d.y, d.x]; });
                   svg.append("g")
                      .attr("transform", "translate(" + margins.left + "," + margins.top + ")");
                   break;
    case 'radial': d3.select('#map').on("mousemove", mousemove).on("mouseup", mouseup);
                   rx = w / 2;
                   ry = h / 2;
                   rotate=0;
                   cluster = d3.layout.cluster()
                     .size([360, ry - 120])
                     .sort(null);
                   diagonal = d3.svg.diagonal.radial()
                     .projection(function(d) { return [d.y, d.x / 180 * Math.PI]; });
                   vis = svg.append("svg:svg")
                     .append("svg:g")
                     .attr("transform", "translate(" + rx + "," + ry + ")");
                   vis.append("svg:path")
                     .attr("class", "arc")
                     .attr("d", d3.svg.arc().innerRadius(ry - 115).outerRadius(ry - 10).startAngle(0).endAngle(2 * Math.PI))
                     .on("mousedown", mousedown);
                    break;
    default: break;
  }

  d3.json('/api/v1/getvdcguestsbycn/'+encodeURIComponent($('#vdc').val())+'.json', function(error, json) {
    switch($('#visualization').val()) {
      case 'domain': root = json;
                     root.x0 = height / 2;
                     root.y0 = 0;
                     function collapse(d) {
                       if (d.children) {
                         d._children = d.children;
                         d._children.forEach(collapse);
                         d.children = null;
                       }
                     }
                     root.children.forEach(collapse);
                     updateTree(root);
                     break;
      case 'radial': nodes = cluster.nodes(json);
                     updateRadial();
                     break;
      default: break;
    }
  });

  spinThatWheel(false);
}

function refreshPage() {
  console.log( "refreshPage called" );
  spinThatWheel(true);

  // get services from backend, for a specific environment as defined in the "env:" tag
  $.getJSON('/api/v1/gethostsperservice/'+getCurrentEnv()+'.json', function( services ) {
    if (services) {
      // it's an obj/hash with a single service as key
      myServices=services;
      // save locally myServices
      if (Modernizr.localstorage) {
        myServices=sortObjectByKey(myServices);
        localStorage["myServices"] = JSON.stringify(myServices);
      }
      updateSwitches();
      // update tags
        $('#tags').html('');
        for (v=0; v<myVDCS.length; v++) {
          if (myVDCS[v].display_name===$('#vdc').val()) {
            var tags=myVDCS[v].tags.split(',');
            for (t = 0; t < tags.length; t++) {
              $('#tags').append('<span class="label label-info">'+tags[t]+'</span>&nbsp;');
            }
          }
        }

      // if autorefresh enabled start another timer
      if ($('#autorefresh-switch').prop('checked')) {
        currentsecond=countdownfrom+1;
        counterTimer=setTimeout(countdown,1000);
      }
      // update D3 bounded data
      drawGraph();
    } else {
      alertThis('No Services found. Check CMDB source or try adding one!','danger');
    }
    spinThatWheel(false);
  });
}

function updateRadial() {
  link = vis.selectAll("path.link")
      .data(cluster.links(nodes))
      .enter().append("svg:path")
      .attr("class", "link")
      .attr("d", diagonal);

  node = vis.selectAll("g.node")
      .data(nodes)
      .enter().append("svg:g")
      .attr("class", "node")
      .attr("transform", function(d) { return "rotate(" + (d.x - 90) + ")translate(" + d.y + ")"; });

  node.append("svg:circle")
      .attr("r", function(d){
        return d.name.match("ExalogicControl") ? 6 : 4;
      })
      .attr("fill", function(d){
        var color='lightblue';
        if (d.type==='compute-node') {
          color='lime';
        } else if (d.type==='vdc') {
          color='blue';
        } else {
          color=d.name.match("ExalogicControl") ? getExalogicControlStatus(d) : "lightblue";
        }
        return color;
      })
      .attr("stroke", "black")
      .attr("stroke-width", "1px")
      .attr("class", function(d) {
        var hostname=d.name.split(".",1)[0];
        return "status_"+hostname;
      });

  node.append("svg:rect")
      .attr("class", function(d) {
        var hostname=d.name.split(".",1)[0];
        return "service_"+hostname;
      })
      .attr("width", "80")
      .attr("height", "16")
      .attr("rx", "2")
      .attr("ry", "2")
      // .attr("fill", "red")
      // .attr("stroke", "red")
      .attr("opacity", "0")
      .attr("transform", "translate(6,-8)");

  node.append("svg:text")
      .attr("dx", function(d) { return d.x < 180 ? 8 : -8; })
      .attr("dy", ".31em")
      .attr("text-anchor", function(d) { return d.x < 180 ? "start" : "end"; })
      .attr("transform", function(d) { return d.x < 180 ? null : "rotate(180)"; })
      .text(function(d) {
        var myname=d.name.split(".",1)[0];
        if (d.name.match("ExalogicControl")) {
          arr=d.name.split(':'); myname=arr[0];
        }
        return myname;
      });
}

function updateTree(source) {
 // Compute the new tree layout.
  var nodes = tree.nodes(root).reverse(),
      links = tree.links(nodes);

  // Normalize for fixed-depth.
  nodes.forEach(function(d) { d.y = d.depth * 180; });

  // Update the nodes…
  var node = svg.selectAll("g.node")
      .data(nodes, function(d) { return d.id || (d.id = ++i); });

  // Enter any new nodes at the parent's previous position.
  var nodeEnter = node.enter().append("g")
      .attr("class", "node")
      .attr("transform", function(d) { return "translate(" + source.y0 + "," + source.x0 + ")"; })
      .on("click", click);

  nodeEnter.append("circle")
      .attr("r", 1e-6)
      .style("fill", function(d) { return d._children ? "lightsteelblue" : "#fff"; });

  nodeEnter.append("text")
      .attr("x", function(d) { return d.children || d._children ? -10 : 10; })
      .attr("dy", ".35em")
      .attr("text-anchor", function(d) { return d.children || d._children ? "end" : "start"; })
      .text(function(d) { return d.name; })
      .style("fill-opacity", 1e-6);

  // Transition nodes to their new position.
  var nodeUpdate = node.transition()
      .duration(duration)
      .attr("transform", function(d) { return "translate(" + d.y + "," + d.x + ")"; });

  nodeUpdate.select("circle")
      .attr("r", 4.5)
      .style("fill", function(d) { return d._children ? "lightsteelblue" : "#fff"; });

  nodeUpdate.select("text")
      .style("fill-opacity", 1);

  // Transition exiting nodes to the parent's new position.
  var nodeExit = node.exit().transition()
      .duration(duration)
      .attr("transform", function(d) { return "translate(" + source.y + "," + source.x + ")"; })
      .remove();

  nodeExit.select("circle")
      .attr("r", 1e-6);

  nodeExit.select("text")
      .style("fill-opacity", 1e-6);

  // Update the links…
  var link = svg.selectAll("path.link")
      .data(links, function(d) { return d.target.id; });

  // Enter any new links at the parent's previous position.
  link.enter().insert("path", "g")
      .attr("class", "link")
      .attr("d", function(d) {
        var o = {x: source.x0, y: source.y0};
        return diagonal({source: o, target: o});
      });

  // Transition links to their new position.
  link.transition()
      .duration(duration)
      .attr("d", diagonal);

  // Transition exiting nodes to the parent's new position.
  link.exit().transition()
      .duration(duration)
      .attr("d", function(d) {
        var o = {x: source.x, y: source.y};
        return diagonal({source: o, target: o});
      })
      .remove();

  // Stash the old positions for transition.
  nodes.forEach(function(d) {
    d.x0 = d.x;
    d.y0 = d.y;
  });
}

function tick() {
  link.attr("x1", function(d) { return d.source.x; })
      .attr("y1", function(d) { return d.source.y; })
      .attr("x2", function(d) { return d.target.x; })
      .attr("y2", function(d) { return d.target.y; });

  node.attr("cx", function(d) { return d.x; })
      .attr("cy", function(d) { return d.y; });
}

// Toggle children on click.
function click(d) {
  if (d.children) {
    d._children = d.children;
    d.children = null;
  } else {
    d.children = d._children;
    d._children = null;
  }
  updateTree(d);
}

// Returns a list of all nodes under the root.
function flatten(root) {
  var nodes = [], i = 0;

  function recurse(node) {
    if (node.children) node.size = node.children.reduce(function(p, v) { return p + recurse(v); }, 0);
    if (!node.id) node.id = ++i;
    nodes.push(node);
    return node.size;
  }

  root.size = recurse(root);
  return nodes;
}

function color(d) {
  if (d._children) {
    // collapsed node
    return "#3182bd";
  } else {
    if (d.children) {
      // compute node background
      return "#FFFFFF";
    } else {
      var hostname=d.name.split(".",1)[0];
      if (hostname.match("ExalogicControl")) {
        // PC/control background
        return "#FFFF00";
      } else {
        // leaf background
        // return "#fd8d3c";
        return get_random_color();
      }
    }
  }
}

function rand(min, max) {
  return min + Math.random() * (max - min);
}

function get_random_color() {
  // var h = rand(1, 120);
  var h=120;
  var s = rand(10, 90);
  var l = rand(10, 90);
  return 'hsl(' + h + ',' + s + '%,' + l + '%)';
}

function mouse(e) {
  // console.log('mouse called');
  return [e.pageX - rx, e.pageY - ry];
}

function mousedown() {
  // console.log('mousedown called');
  m0 = mouse(d3.event);
  d3.event.preventDefault();
}

function mousemove() {
  if (m0) {
    var m1 = mouse(d3.event),
        dm = Math.atan2(cross(m0, m1), dot(m0, m1)) * 180 / Math.PI,
        tx = "translate3d(0," + (ry - rx) + "px,0)rotate3d(0,0,0," + dm + "deg)translate3d(0," + (rx - ry) + "px,0)";
    svg
        .style("-moz-transform", tx)
        .style("-ms-transform", tx)
        .style("-webkit-transform", tx);
  }
}

function mouseup() {
  // console.log('mouseup called');
  if (m0) {
    var m1 = mouse(d3.event),
        dm = Math.atan2(cross(m0, m1), dot(m0, m1)) * 180 / Math.PI,
        tx = "rotate3d(0,0,0,0deg)";

    rotate += dm;
    if (rotate > 360) rotate -= 360;
    else if (rotate < 0) rotate += 360;
    m0 = null;

    svg
        .style("-moz-transform", tx)
        .style("-ms-transform", tx)
        .style("-webkit-transform", tx);

    vis
        .attr("transform", "translate(" + rx + "," + ry + ")rotate(" + rotate + ")")
      .selectAll("g.node text")
        .attr("dx", function(d) { return (d.x + rotate) % 360 < 180 ? 8 : -8; })
        .attr("text-anchor", function(d) { return (d.x + rotate) % 360 < 180 ? "start" : "end"; })
        .attr("transform", function(d) { return (d.x + rotate) % 360 < 180 ? null : "rotate(180)"; });
  }
}

function cross(a, b) {
  return a[0] * b[1] - a[1] * b[0];
}

function dot(a, b) {
  return a[0] * b[0] + a[1] * b[1];
}

function switchAll(state) {
  $('.myswitches').bootstrapToggle(state);
}

function switchToggled() {
  console.log('switch toggled');
}
