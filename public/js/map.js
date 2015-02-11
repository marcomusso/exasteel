function initPage() {
  console.log( "initPage called" );
  // Enable tooltips
  $(function () {
    $('[data-toggle="tooltip"]').tooltip();
  });

 $.getJSON('/api/v1/getvdcs.json', function( vdcs ) {
    if (vdcs) {
      MyVDCS=vdcs;
      var select = document.getElementById("vdc");
      for (i=0; i<MyVDCS.length; i++) {
        console.log(MyVDCS[i].display_name);
        select.options[select.options.length] = new Option(MyVDCS[i].display_name+' - '+MyVDCS[i].asset_description, MyVDCS[i].display_name);
      }
    }
  });

  var width = $('#map').width();
  var height = $('#map').height();

  var color = d3.scale.category20();

  var force = d3.layout.force()
      .linkDistance(10)
      .linkStrength(2)
      .size([width, height]);

  var svg = d3.select("#map").append("svg")
      .attr("width", width)
      .attr("height", height);

  d3.json("/miserables.json", function(error, graph) {
    var nodes = graph.nodes.slice(),
        links = [],
        bilinks = [];

    graph.links.forEach(function(link) {
      var s = nodes[link.source],
          t = nodes[link.target],
          i = {}; // intermediate node
      nodes.push(i);
      links.push({source: s, target: i}, {source: i, target: t});
      bilinks.push([s, i, t]);
    });

    force
        .nodes(nodes)
        .links(links)
        .start();

    var link = svg.selectAll(".link")
        .data(bilinks)
      .enter().append("path")
        .attr("class", "link");

    var node = svg.selectAll(".node")
        .data(graph.nodes)
      .enter().append("circle")
        .attr("class", "node")
        .attr("r", 5)
        .style("fill", function(d) { return color(d.group); })
        .call(force.drag);

    node.append("title")
        .text(function(d) { return d.name; });

    force.on("tick", function() {
      link.attr("d", function(d) {
        return "M" + d[0].x + "," + d[0].y
            + "S" + d[1].x + "," + d[1].y
            + " " + d[2].x + "," + d[2].y;
      });
      node.attr("transform", function(d) {
        return "translate(" + d.x + "," + d.y + ")";
      });
    });
  });
////


  // if another vdc get selected...
  $('#vdc').change(function() {
    refreshPage();
  });
}

function refreshPage() {
  console.log( "refreshPage called" );

  // update D3 bounded data
  $('#map').html('');

}