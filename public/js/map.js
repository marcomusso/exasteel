var MyVDCS;
var margins = {
  top: 10,
  bottom: 10,
  left: 10,
  right: 10
};
var i=0;
var width, height, w, h;
var link, node, root, force, vis, tip;
var barHeight, barWidth, duration;
var rx, ry, m0, rotate = 0;
var cluster, nodes;
var svg;

// refresh timers
  var refreshInterval = countdownfrom*1000; // global default page refresh, milliseconds!!! see default.js
  var refreshTimer;
  var counterTimer;

function initPage() {
  console.log( "initPage called" );
  // Enable tooltips
  // $('[data-toggle="tooltip"]').tooltip();

  if ($('#visualization').length) { $("#visualization").val(mySessionData['mapvisualization']); }

  $.getJSON('/api/v1/getvdcs.json', function( vdcs ) {
    if (vdcs) {
      MyVDCS=vdcs;
      var select = document.getElementById("vdc");
      for (i=0; i<MyVDCS.length; i++) {
        // console.log(MyVDCS[i].display_name);
        select.options[select.options.length] = new Option(MyVDCS[i].display_name+' - '+MyVDCS[i].asset_description, MyVDCS[i].display_name);
      }
      // display tags FOR FIRST VDC
        var tags=MyVDCS[0].tags.split(',');
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
    refreshPage();
  });
  // if the user wants to change the visualization
  $('#visualization').change(function() {
    mySessionData['mapvisualization']=$("#visualization").val();
    setSessionData();
    refreshPage();
  });
  $('.myswitches').change(function() {
    // console.log('Toggle '+$(this).attr('id')+' to '+$(this).prop('checked'));
    switch ($(this).attr('id')) {
      case 'BSMA0':
        if ($(this).prop('checked')) {
          $('.service_sapvxp008').attr("fill","green");
          $('.service_sapvxp008').attr("opacity","0.8");
          $('.service_sapvxp009').attr("fill","green");
          $('.service_sapvxp009').attr("opacity","0.8");
          $('.service_sapvxp010').attr("fill","green");
          $('.service_sapvxp010').attr("opacity","0.8");
          $('.service_sapvxp011').attr("fill","green");
          $('.service_sapvxp011').attr("opacity","0.8");
          $('.service_sapvxp012').attr("fill","green");
          $('.service_sapvxp012').attr("opacity","0.8");
        } else {
          $('.service_sapvxp008').attr("opacity","0");
          $('.service_sapvxp009').attr("opacity","0");
          $('.service_sapvxp010').attr("opacity","0");
          $('.service_sapvxp011').attr("opacity","0");
          $('.service_sapvxp012').attr("opacity","0");
        }
        break;
      case 'PDCR0':
        if ($(this).prop('checked')) {
          $('.service_sapvxp037').attr("fill","yellow");
          $('.service_sapvxp037').attr("opacity","0.8");
          $('.service_sapvxp038').attr("fill","yellow");
          $('.service_sapvxp038').attr("opacity","0.8");
          $('.service_sapvxp039').attr("fill","yellow");
          $('.service_sapvxp039').attr("opacity","0.8");
          $('.service_sapvxp040').attr("fill","yellow");
          $('.service_sapvxp040').attr("opacity","0.8");
          $('.service_sapvxp041').attr("fill","yellow");
          $('.service_sapvxp041').attr("opacity","0.8");
        } else {
          $('.service_sapvxp037').attr("opacity","0");
          $('.service_sapvxp038').attr("opacity","0");
          $('.service_sapvxp039').attr("opacity","0");
          $('.service_sapvxp040').attr("opacity","0");
          $('.service_sapvxp041').attr("opacity","0");
        }
        break;
    }
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
  // svg=vis;

  switch($('#visualization').val()) {
    case 'bars': barHeight = 20;
                 barWidth = w * 0.9;
                 duration = 300;
                 svg = svg.append("g")
                  .attr("transform", "translate(" + margins.left + "," + margins.top + ")");
                 tree = d3.layout.tree()
                   .nodeSize([0, 20]);
                 diagonal = d3.svg.diagonal()
                   .projection(function(d) { return [d.y, d.x]; });
                 break;
    case 'tree': d3.select('#map').on("mousemove", mousemove).on("mouseup", mouseup);
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
    case 'force': force = d3.layout.force()
                    .on("tick", tick)
                    .charge(function(d) { return d._children ? 100 : -30; })
                    .linkDistance(function(d) { return d.target._children ? 80 : 30; })
                    .linkStrength(function(link) {
                      if (link.source.type === 'vdc') return 0.1;
                      if (link.source.type === 'compute-node') return 0.5;
                      return 1;
                    })
                    .size([w, h - 160]);
                  break;
    default: break;
  }

  d3.json('/api/v1/getvdcguestsbycn/'+encodeURIComponent($('#vdc').val())+'.json', function(error, json) {
    switch($('#visualization').val()) {
      case 'bars':  json.x0 = 0;
                    json.y0 = 0;
                    updateBars(root = json);
                    break;
      case 'tree': nodes = cluster.nodes(json);
                   updateTree();
                   break;
      case 'force': root = json;
                    root.fixed = true;
                    root.x = w / 2 + margins.left;
                    root.y = h / 2 - 80 + margins.top;
                    updateForce();
                    break;
    }
  });

  spinThatWheel(false);
}

function refreshPage() {
  console.log( "refreshPage called" );
  spinThatWheel(true);

  // update tags
    $('#tags').html('');
    for (v=0; v<MyVDCS.length; v++) {
      if (MyVDCS[v].display_name===$('#vdc').val()) {
        var tags=MyVDCS[v].tags.split(',');
        for (t = 0; t < tags.length; t++) {
          $('#tags').append('<span class="label label-info">'+tags[t]+'</span>&nbsp;');
        }
      }
    }

  // if autorefresh enables start another timer
  if ($('#autorefresh-switch').prop('checked')) {
    currentsecond=countdownfrom+1;
    counterTimer=setTimeout(countdown,1000);
  }
  // update D3 bounded data
  drawGraph();
}

function updateForce() {
  var nodes = flatten(root),
      links = d3.layout.tree().links(nodes);

  // Restart the force layout.
  force
      .nodes(nodes)
      .links(links)
      .start();

  // Update the links…
  link = vis.selectAll("line.link")
      .data(links, function(d) { return d.target.id; });

  // Enter any new links.
  link.enter().insert("svg:line", ".node")
      .attr("class", "link")
      .attr("x1", function(d) { return d.source.x; })
      .attr("y1", function(d) { return d.source.y; })
      .attr("x2", function(d) { return d.target.x; })
      .attr("y2", function(d) { return d.target.y; });

  // Exit any old links.
  link.exit().remove();

  // Update the nodes…
  node = vis.selectAll("circle.node")
      .data(nodes, function(d) { return d.id; })
      .style("fill", color);

  node.transition()
      .attr("r", function(d) {
        if (d.type === 'vdc') return 10;
        if (d.type === 'compute-node') return d.cpus ? d.cpus*1.5 : 10;
        return d.children ? 5 : 10;
      });

  // Enter any new nodes.
  node.enter()
      .append("svg:circle")
      .attr("class", "node")
      .attr("cx", function(d) { return d.x; })
      .attr("cy", function(d) { return d.y; })
      .attr("r", function(d) {
        if (d.type === 'vdc') return 10;
        if (d.type === 'compute-node') return d.cpus/2;
        return d.children ? 5 : 10;
      })
      .style("fill", color)
      .on("click", clickTree)
      .on('mouseover', function(d){
        console.log('tip.show');
        tip.show();
      })
      .on('mouseout', function(d) {
        console.log('tip.hide');
        tip.hide();
      })
      .call(force.drag);

  // Exit any old nodes.
  node.exit().remove();
}

function updateBars(source) {
  // Compute the flattened node list. TODO use d3.layout.hierarchy.
  var nodes = tree.nodes(root);

  // var h = Math.max(500, nodes.length * barHeight + margins.top + margins.bottom);

  d3.select("svg").transition()
      .duration(duration)
      .attr("height", h);

  d3.select(self.frameElement).transition()
      .duration(duration)
      .style("height", height + "px");

  // Compute the "layout".
  nodes.forEach(function(n, i) {
    n.x = i * barHeight;
  });

  // Update the nodes…
  var node = svg.selectAll("g.node")
      .data(nodes, function(d) { return d.id || (d.id = ++i); });

  var nodeEnter = node.enter().append("g")
      .attr("class", "node")
      .attr("transform", function(d) { return "translate(" + source.y0 + "," + source.x0 + ")"; })
      .style("opacity", 1e-6);

  // Enter any new nodes at the parent's previous position.
  nodeEnter.append("rect")
      .attr("y", -barHeight / 2)
      .attr("height", barHeight)
      .attr("width", barWidth)
      .style("fill", color)
      .on("click", clickBars);

  nodeEnter.append("text")
      .attr("dy", 3.5)
      .attr("dx", 5.5)
      .text(function(d) {
        var hostname=d.name.split(".",1)[0];
        if (d.cpus && d.memory) {
          return hostname+': '+d.cpus+' LCPUs ('+d.totalProcessorCores+'*'+d.threadsPerCore+'), RAM '+byte2human(d.memory*1024*1024,mySessionData['units']);
        } else {
          return hostname;
        }
      });

  // Transition nodes to their new position.
  nodeEnter.transition()
      .duration(duration)
      .attr("transform", function(d) { return "translate(" + d.y + "," + d.x + ")"; })
      .style("opacity", 1);

  node.transition()
      .duration(duration)
      .attr("transform", function(d) { return "translate(" + d.y + "," + d.x + ")"; })
      .style("opacity", 1)
    .select("rect")
      .style("fill", color);

  // Transition exiting nodes to the parent's new position.
  node.exit().transition()
      .duration(duration)
      .attr("transform", function(d) { return "translate(" + source.y + "," + source.x + ")"; })
      .style("opacity", 1e-6)
      .remove();

  // Update the links…
  var link = svg.selectAll("path.link")
      .data(tree.links(nodes), function(d) { return d.target.id; });

  // Enter any new links at the parent's previous position.
  link.enter().insert("path", "g")
      .attr("class", "link")
      .attr("d", function(d) {
        var o = {x: source.x0, y: source.y0};
        return diagonal({source: o, target: o});
      })
    .transition()
      .duration(duration)
      .attr("d", diagonal);

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

function updateTree() {
  link = vis.selectAll("path.link")
      .data(cluster.links(nodes))
      .enter().append("svg:path")
      .attr("class", "link")
      .attr("d", diagonal);

  //Set up tooltip
  tip = d3.tip()
    .attr('class', 'd3-tip')
    .offset([-10, 0])
    .html(function(d) {
      if (d.type === 'vdc') return d.name.split(".",1)[0]+': '+d.cnCount+' CN';
      if (d.type === 'compute-node') return d.name.split(".",1)[0]+': '+d.cpus+' LCPUs ('+d.totalProcessorCores+'*'+d.threadsPerCore+'), RAM '+byte2human(d.memory*1024*1024,mySessionData['units']);
      return d.name.split(".",1)[0];
    });
  vis.call(tip);

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
        return d.name.match("ExalogicControl") ? "red" : "lightblue";
      })
      .on('mouseover', tip.show)
      .on('mouseout', tip.hide);

  node.append("svg:rect")
      .attr("class", function(d) {
        var hostname=d.name.split(".",1)[0];
        return "service_"+hostname;
        // return "service";
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
      .text(function(d) { return d.name.split(".",1)[0]; });
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
function clickBars(d) {
  if (d.children) {
    d._children = d.children;
    d.children = null;
  } else {
    d.children = d._children;
    d._children = null;
  }
  updateBars(d);
}

// Toggle children on click.
function clickTree(d) {
  console.log('clickTree called');
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

// function color(d) {
//   if (d._children) {
//     return "#3182bd";     // collapsed node
//   } else {
//     if (d.children) {
//         return "#c6dbef"; // node background
//     } else {
//       var hostname=d.name.split(".",1)[0];
//       if (hostname.match("ExalogicControl")) {
//         return "#333333"; // PC/control background
//       } else {
//         return "#fd8d3c"; // leaf background
//       }
//     }
//   }
// }

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
  console.log('mouse called');
  return [e.pageX - rx, e.pageY - ry];
}

function mousedown() {
  console.log('mousedown called');
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
  console.log('mouseup called');
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