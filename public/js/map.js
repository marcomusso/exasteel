var MyVDCS;
var margin = {
  top: 10,
  bottom: 10,
  left: 10,
  right: 10
};
var tree;
var root;
var i=0;
var rx, ry, m0, rotate = 0;
var width, height, w, h;
var nodes, link, node;
var barHeight, barWidth, duration;

function initPage() {
  console.log( "initPage called" );
  // Enable tooltips
  $('[data-toggle="tooltip"]').tooltip();

  $.getJSON('/api/v1/getvdcs.json', function( vdcs ) {
    if (vdcs) {
      MyVDCS=vdcs;
      var select = document.getElementById("vdc");
      for (i=0; i<MyVDCS.length; i++) {
        // console.log(MyVDCS[i].display_name);
        select.options[select.options.length] = new Option(MyVDCS[i].display_name+' - '+MyVDCS[i].asset_description, MyVDCS[i].display_name);
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
}


function drawGraph() {

  $('#map').html('');

  width=$('#map').width();    // before margins
  height=$('#map').height();  // before margins
  w=width - margin.right - margin.left;   // after margins
  h=height - margin.top - margin.bottom;  // after margins

  barHeight = 20;
  barWidth = w * 0.9;
  duration = 300;

  tree = d3.layout.tree()
      .nodeSize([0, 20]);

  diagonal = d3.svg.diagonal()
      .projection(function(d) { return [d.y, d.x]; });

  svg = d3.select("#map").append("svg")
      .attr("width", width + margin.left + margin.right)
    .append("g")
      .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

  d3.json('/api/v1/getvdcguestsbycn/'+$('#vdc').val()+'.json', function(error, json) {
    json.x0 = 0;
    json.y0 = 0;
    update(root = json);
  });
  spinThatWheel(false);
}

function refreshPage() {
  console.log( "refreshPage called" );
  spinThatWheel(true);

  // update D3 bounded data
  drawGraph();
}

function update(source) {

  // Compute the flattened node list. TODO use d3.layout.hierarchy.
  var nodes = tree.nodes(root);

  var height = Math.max(500, nodes.length * barHeight + margin.top + margin.bottom);

  d3.select("svg").transition()
      .duration(duration)
      .attr("height", height);

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
      .on("click", click);

  nodeEnter.append("text")
      .attr("dy", 3.5)
      .attr("dx", 5.5)
      .text(function(d) {
        var hostname=d.name.split(".",1)[0];
        if (d.type === 'compute-node') {
          return hostname+' ('+d.cpus+' LCPUs ('+d.totalProcessorCores+'*'+d.threadsPerCore+'), RAM '+byte2human(d.memory*1024*1024,mySessionData['unit'])+')';
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

// Toggle children on click.
function click(d) {
  if (d.children) {
    d._children = d.children;
    d.children = null;
  } else {
    d.children = d._children;
    d._children = null;
  }
  update(d);
}

function color(d) {
  if (d._children) {
    return "#3182bd";     // collapsed node
  } else {
    if (d.children) {
        return "#c6dbef"; // node background
    } else {
      var hostname=d.name.split(".",1)[0];
      if (hostname.match("ExalogicControl")) {
        return "#333333"; // PC/control background
      } else {
        return "#fd8d3c"; // leaf background
      }
    }
  }
}