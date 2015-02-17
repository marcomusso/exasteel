var MyVDCS;
var margin = {
  top: 10,
  bottom: 10,
  left: 10,
  right: 10
};
var i=0;
var width, height, w, h;
var link, node, root, force, vis, tip;

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
}

function drawGraph() {

  $('#map').html('');

  width=$('#map').width();    // before margins
  height=$('#map').height();  // before margins
  w=width - margin.right - margin.left;   // after margins
  h=height - margin.top - margin.bottom;  // after margins

  force = d3.layout.force()
      .on("tick", tick)
      .charge(function(d) { return d._children ? 100 : -30; })
      .linkDistance(function(d) { return d.target._children ? 80 : 30; })
      .linkStrength(function(link) {
        if (link.source.type === 'vdc') return 0.1;
        if (link.source.type === 'compute-node') return 0.5;
        return 1;
      })
      .size([w, h - 160]);

  vis = d3.select("#map").append("svg:svg")
      .attr("width", w)
      .attr("height", h);

  //Set up tooltip
  tip = d3.tip()
      .attr('class', 'd3-tip')
      .offset([-10, 0])
      .html(function(d) {
        return d.name.split(".",1)[0];
      });
  vis.call(tip);

  d3.json('/api/v1/getvdcguestsbycn/'+$('#vdc').val()+'.json', function(error, json) {
    root = json;
    root.fixed = true;
    root.x = w / 2;
    root.y = h / 2 - 80;
    update();
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

  // update D3 bounded data
  drawGraph();
}

function update() {
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
      .attr("r", function(d) { return d.children ? 5 : 10; });

  // Enter any new nodes.
  node.enter()
        // .append("g")
      .append("svg:circle")
      .attr("class", "node")
      .attr("cx", function(d) { return d.x; })
      .attr("cy", function(d) { return d.y; })
      .attr("r", function(d) { return d.children ? 5 : 10; })
      .style("fill", color)
      .on("click", click)
      .on('mouseover', tip.show)
      .on('mouseout', tip.hide)
      .call(force.drag);

  // node.append("svg:circle")
  //     .attr("cx", function(d) { return d.x; })
  //     .attr("cy", function(d) { return d.y; })
  //     .attr("r", function(d) { return d.children ? 5 : 10; })
  //     .style("fill", color);

  // label
  // node.append("text")
  //     .attr("dx", 10)
  //     .attr("dy", ".35em")
  //     .text(function(d) { return d.name; });

  // Exit any old nodes.
  node.exit().remove();
}

function tick() {
  link.attr("x1", function(d) { return d.source.x; })
      .attr("y1", function(d) { return d.source.y; })
      .attr("x2", function(d) { return d.target.x; })
      .attr("y2", function(d) { return d.target.y; });

  node.attr("cx", function(d) { return d.x; })
      .attr("cy", function(d) { return d.y; });

  // d3.selectAll("circle").attr("cx", function (d) {
  //      return d.x;
  //  })
  //      .attr("cy", function (d) {
  //      return d.y;
  //  });

  // d3.selectAll("text").attr("x", function (d) {
  //       return d.x;
  //   })
  //   .attr("y", function (d) {
  //       return d.y;
  //   });
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
  update();
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