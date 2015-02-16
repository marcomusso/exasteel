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
var cluster;
var nodes, link, node;

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
      drawCircles();
    }
  }).fail(function(){
    alertThis('Error in getting VDC list','danger');
  });

  // if another vdc get selected...
  $('#vdc').change(function() {
    refreshPage();
  });

  d3.select(window)
      .on("mousemove", mousemove)
      .on("mouseup", mouseup);
}


function drawCircles() {

  $('#map').html('');

  width=$('#map').width();    // before margins
  height=$('#map').height();  // before margins
  w=width - margin.right - margin.left;   // after margins
  h=height - margin.top - margin.bottom;  // after margins

  rx = w / 2;
  ry = h / 2;
  rotate=0;

  cluster = d3.layout.cluster()
      .size([360, ry - 120])
      .sort(null);

  diagonal = d3.svg.diagonal.radial()
      .projection(function(d) { return [d.y, d.x / 180 * Math.PI]; });

  svg = d3.select("#map").append("div")
      .style("width", w + "px")
      .style("height", w + "px");

  vis = svg.append("svg:svg")
      .attr("width", w)
      .attr("height", w)
    .append("svg:g")
      .attr("transform", "translate(" + rx + "," + ry + ")");

  vis.append("svg:path")
      .attr("class", "arc")
      .attr("d", d3.svg.arc().innerRadius(ry - 115).outerRadius(ry).startAngle(0).endAngle(2 * Math.PI))
      .on("mousedown", mousedown);

  d3.json('/api/v1/getvdcguestsbycn/'+$('#vdc').val()+'.json', function(error, json) {
    nodes = cluster.nodes(json);

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
          return d.name.match("ExalogicControl") ? 5 : 3;
        })
        .attr("fill", function(d){
          return d.name.match("ExalogicControl") ? "red" : "darkblue";
        });

    node.append("svg:text")
        .attr("dx", function(d) { return d.x < 180 ? 8 : -8; })
        .attr("dy", ".31em")
        .attr("text-anchor", function(d) { return d.x < 180 ? "start" : "end"; })
        .attr("transform", function(d) { return d.x < 180 ? null : "rotate(180)"; })
        .text(function(d) { return d.name.split(".",1)[0]; });
  });
  spinThatWheel(false);
}

function refreshPage() {
  console.log( "refreshPage called" );
  spinThatWheel(true);

  // update D3 bounded data
  drawCircles();
}

function mouse(e) {
  return [e.pageX - rx, e.pageY - ry];
}

function mousedown() {
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