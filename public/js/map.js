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
var r,pack,vis;
var diagonal;
var width, height, w, h;

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
}


function drawCircles() {
  width=$('#map').width();    // before margins
  height=$('#map').height();  // before margins
  w=width - margin.right - margin.left;   // after margins
  h=height - margin.top - margin.bottom;  // after margins

  r = 720;
  var x = d3.scale.linear().range([0, r]);
  var y = d3.scale.linear().range([0, r]);

  pack = d3.layout.pack()
      .size([r, r])
      .value(function(d) { return 60; });

  vis = d3.select("#map").insert("svg:svg", "h2")
      .attr("width", w)
      .attr("height", h)
      .append("svg:g")
      .attr("transform", "translate(" + (w - r) / 2 + "," + (h - r) / 2 + ")");


  d3.json('/api/v1/getvdcguestsbycn/'+MyVDCS[0].display_name+'.json', function(error, json) {
    node = root = json;

    var nodes = pack.nodes(root);

    vis.selectAll("circle")
        .data(nodes)
      .enter().append("svg:circle")
        .attr("class", function(d) { return d.children ? "parent" : "child"; })
        .attr("cx", function(d) { return d.x; })
        .attr("cy", function(d) { return d.y; })
        .attr("r", function(d) { return d.r; })
        .on("click", function(d) { return zoom(node == d ? root : d); });

    vis.selectAll("text")
        .data(nodes)
      .enter().append("svg:text")
        .attr("class", function(d) { return d.children ? "parent" : "child"; })
        .attr("x", function(d) { return d.x; })
        .attr("y", function(d) { return d.y; })
        .attr("dy", ".35em")
        .attr("text-anchor", "middle")
        .style("opacity", function(d) { return d.r > 20 ? 1 : 0; })
        .text(function(d) { return d.name; });

    d3.select(window).on("click", function() { zoom(root); });
  });
}

function refreshPage() {
  console.log( "refreshPage called" );
  spinThatWheel(true);

  // update D3 bounded data
  d3.json('/api/v1/getvdcguestsbycn/'+$('#vdc').val()+'.json', function(error, json) {
    root = json;
    //...
  });

}

function zoom(d, i) {
  var k = r / d.r / 2;
  x.domain([d.x - d.r, d.x + d.r]);
  y.domain([d.y - d.r, d.y + d.r]);

  var t = vis.transition()
      .duration(d3.event.altKey ? 7500 : 750);

  t.selectAll("circle")
      .attr("cx", function(d) { return x(d.x); })
      .attr("cy", function(d) { return y(d.y); })
      .attr("r", function(d) { return k * d.r; });

  t.selectAll("text")
      .attr("x", function(d) { return x(d.x); })
      .attr("y", function(d) { return y(d.y); })
      .style("opacity", function(d) { return k * d.r > 20 ? 1 : 0; });

  node = d;
  d3.event.stopPropagation();
}