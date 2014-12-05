function fillKPI(element) {
  console.log('fillKPI called on '+element);
  var w = $(element).width();
  var h = 100;
  var dataset = [
          {
            x: 5,
            y: 20,
            r: 10,
            c: "black"
          },
          {
            x: 480,
            y: 90,
            r: 20,
            c: "#43f5e5"
          },
          {
            x: 250,
            y: 50,
            r: 15,
            c: "magenta"
          },
          {
            x: 100,
            y: 33,
            r: 7,
            c: "green"
          },
          {
            x: 330,
            y: 95,
            r: 18,
            c: "yellow"
          },
          {
            x: 410,
            y: 12,
            r: 19,
            c: "red"
          },
          {
            x: 475,
            y: 44,
            r: 25,
            c: "gray"
          },
          {
            x: 25,
            y: 67,
            r: 12,
            c: "blue"
          },
          {
            x: 85,
            y: 21,
            r: 5,
            c: "darkblue"
          },
          {
            x: 220,
            y: 88,
            r: 3,
            c: "orange"
          }
          ];
  var xScale = d3.scale.linear()
             .domain([0, d3.max(dataset, function(d) { return d.x; })])
             .range([0, w]);

  var yScale = d3.scale.linear()
             .domain([0, d3.max(dataset, function(d) { return d.y; })])
             .range([0, h]);
  var svg = d3.select(element)
      .append("svg")
      .attr("width", "100%")
      .attr("height", h);
  svg.selectAll("circle")
    .data(dataset)
    .enter()
    .append("circle")
    .attr("cx", w / 2)
    .attr("cy", h / 2)
    .attr("r", 1)
    // explode from the middle
    .transition()
    .duration(2000)
    .attr("cx", function(d) {
      return xScale(d.x);
    })
    .attr("r", function(d) {
      return d.r*2;
    })
    .attr("cy", function(d) {
      return yScale(d.y);
    })
    .attr("fill", function(d) {
     return d.c;
    })
    // center x in the middle
    .transition()
    .duration(1000)
    .attr("cx", function(d) {
      return w/2;
    })
    // all the way down in the middle, zoome 5x
    .transition()
    .duration(2000)
    .attr("cy", function(d) {
      return h;
    })
    .attr("r", function(d) {
      return d.r*5;
    })
    // zoom 3x and go to the original coordinates
    .transition()
    .duration(1000)
    .attr("cx", function(d) {
    return xScale(d.x);
    })
    .attr("r", function(d) {
     return d.r*3;
    })
    .attr("cy", function(d) {
     return yScale(d.y);
    });
}

function initPage() {
  console.log( "initPage called" );
  // Enable tooltips
  $(function () {
    $('[data-toggle="tooltip"]').tooltip();
  });

  var accounts = {
      "TEST": "",
      "PERFORMACETEST": "",
      "DEV": "",
      "TEMPLATES": "",
      "MANAGEMENT": ""
  };
  for (var account in accounts)  {
    fillKPI('#'+account+'_kpi');
  }
}

function refreshPage() {
  console.log( "refreshPage called" );
}