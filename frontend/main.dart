import 'package:aqiapp/model/Database.dart';
import 'dart:convert';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_circular_chart/flutter_circular_chart.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:http/http.dart';
import 'dart:io';
import 'dart:async' show Future;
import 'globals.dart' as globals;
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:location/location.dart';
import 'dart:math' show cos, sqrt, asin;

final GlobalKey<AnimatedCircularChartState> _chartKey =
    new GlobalKey<AnimatedCircularChartState>();
//------------------------------------------- DATABASE FUNCTIONS ---------------------------------------------------D

  final dbHelper = DatabaseHelper.instance;

  // Description: Adds a city to the list of favourites in our database
  void _addFav(String city, String state, double lat, double long) async { 
    // deletes city just in case the city already exists
    dbHelper.delete(city + state);
    Map<String, dynamic> row = {
      DatabaseHelper.columnId: city + state,
      DatabaseHelper.columnLat  : lat,
      DatabaseHelper.columnLong  : long,
      DatabaseHelper.columnCity : city,
    };
    final id = await dbHelper.insert(row);
    print('inserted row id: $id');
  }

  void _deleteFav(String id) async {
    final rowsDeleted = await dbHelper.delete(id);
    print('deleted $rowsDeleted row(s): row $id');
  }
  void _queryAllFavs() async {
    final allRows = await dbHelper.queryAllRows();
    print('query all rows:');
    allRows.forEach((row) => print(row));
  }
  void _deleteAllFavs() async {
    final allRows = await dbHelper.queryAllRows();
    for (Map<String, dynamic> row in allRows){
      _deleteFav(row['_id']);
    }
    print('Database has been cleared');
  }

//----------------------------------------------- CLASSES ------------------------------------------------------

// Description: The following objects gold relavent information the air qulaity of reporting area.
class cityAQI {
  
  String city; // name of city/reporting area | ex.'Austin'
  String state; // the US state in which the reporting area is contained | ex.'TX'
  double long; // the longitude value in degrees of this location | ex.-97.7636
  double lat; // the latitude value in degrees of this location | ex.30.2279
  int aqi; // the US EPA calculated value for air quality, value range from 0-500 | ex.116
  int catNum; // the category number from 1 to 7 where each number is associated with a category name | ex.2
  String catName;// the name of the category associated with this air quality | ex.'moderate'
  String primPollutant; // the name of the pollutant which effects one's health most drastically | ex.'PM 2.5'
  var pollConc; // the concentrations of every pollutant in the area | ex. {'PM2.5': 4, 'OZONE': 9}
  String date; // the date observed occured | ex. 2019.08-16
  String timeZone; // the time zone the | ex. -11
  bool actionDay;

  cityAQI({this.city, this. state, this.long, this.lat, this.aqi, this.catNum, this.catName, this.primPollutant, this.pollConc,  this.date, this.timeZone, this.actionDay});
  factory cityAQI.fromJson(Map<String, dynamic> parsedJson) {
    return cityAQI(
        city: parsedJson['ReportingArea'],
        state: parsedJson['StateCode'],
        long: parsedJson['Longitude'],
        lat: parsedJson['Latitude'],
        aqi: parsedJson['AQI'],
        catNum: parsedJson['Category']['Number'],
        catName: parsedJson['Category']['Name'],
        primPollutant: parsedJson['ParameterName'],
        pollConc: parsedJson['pollConc'],
        date: parsedJson['DateObserved'],
        timeZone: parsedJson['LocalTimeZone'],
        actionDay: parsedJson['ActionDay']);
  }
}



//------------------------------------------------- FUNCTIONS ------------------------------------------------------

// Description: This function determines the current AQI information for a given city based on the coordinates
// Input: This function takes in a lat and long which are both doubles
// Return: This function returns a cityAQI object with all the AQI information for the designated reporting area
Future<cityAQI> _makeGetRequest(double lat, double long) async {
  // values for the geobound of a designated city
  // Assumption: each city is a 20x20 mile square (0.15 deg ~ 10 mi)
  double minX = lat - 0.2;
  double maxX = lat + 0.2;
  double minY = long - 0.2;
  double maxY = long + 0.2;

  // base url for AirNow current air quality API 
  String currBase = 'http://www.airnowapi.org/aq/observation/latLong/current/?format=application/json';
  // inputing query parameter
  String currUrl = currBase + '&latitude=' + lat.toString() + '&longitude=' + long.toString() + '&distance=25&API_KEY=5193A560-1A7C-4A65-9B31-AEB3D235BB4F';
  Response response1 = await get(currUrl);
  
  // the status of the get request
  int statusCode = response1.statusCode;
  
  // if the request passes
  if (statusCode == 200){
    var currBody = json.decode(response1.body);
    
    // check if an emepty array was returned 
    if(currBody.length == 0){
      return null;
    }
    var now = new DateTime.now();
    var formatter = new DateFormat('yyyy-MM-dd');
    String endDate = formatter.format(now);
    String startDate = endDate;

    // set hour time frame in which we want to exmaine
    int hour = now.hour;
    int prevHour = now.hour - 1;

    // check if we overflow onto the previous day
    if (hour == 0){
      prevHour = 23;
      final yesterday = new DateTime(now.year, now.month, now.day);
      startDate = formatter.format(yesterday);
    }
    
    // base url for AirNow concentration measuring stations API
    String concBase = 'http://www.airnowapi.org/aq/data/?startDate=';
    // inputing query parameter
    String concUrl = concBase + startDate + 'T' + prevHour.toString() + '&endDate=' + endDate + 'T' + hour.toString() + '&parameters=OZONE,PM25,PM10,CO,NO2,SO2&BBOX=' + minY.toStringAsFixed(3) + ',' +  minX.toStringAsFixed(3) + ',' + maxY.toStringAsFixed(3) + ',' +  maxX.toStringAsFixed(3) + '&dataType=C&format=application/json&verbose=0&nowcastonly=1&API_KEY=5193A560-1A7C-4A65-9B31-AEB3D235BB4F';
    Response response2 = await get(concUrl);
    var concBody = json.decode(response2.body);
    int statusCode = response2.statusCode;
    // check if response passed
    if (statusCode == 200){
      var concMap = new Map();
      for(var i = 0; i < concBody.length; i++){
        String param = concBody[i]['Parameter'];
          if(param == 'OZONE'){
            param = 'O3';
          }
        // if there is a duplicate for a given polluntat we save the higher value to be associated with the city
        if (concMap.containsKey(param) && concMap[param] > concBody[i]['Value']){
            concMap[param] = concBody[i]['Value'];
        } else { // otherwise we add this pollutant to the map
            concMap[param] = concBody[i]['Value'];
          }
      } 
      // creates a city object from the request
      cityAQI city = new cityAQI.fromJson(currBody[0]);
      // sets the concentrations of the pollutants for this new cityAQI object
      city.pollConc = concMap;
      _addFav(city.city, city.state, city.lat, city.long);
      _queryAllFavs();
      _addFav(city.city, city.state, city.lat, city.long);
      _deleteFav(city.city + city.state);
      _queryAllFavs();
      return city; 
    }
  }
  return null;
}


// Description: This function determines AQI forecast for the maximum possible amount fo days for a city or reporting are
// Input: This function takes in a lat and long which are both doubles
// Return: This function returns a list of cityAQI objects each for a different day, with all the AQI information for the designated reporting area
Future<List> _forecast(double lat, double long) async {

  List forecastList = [];
  
  // base url for AirNow air quality index forecast of a given city
  String forcBase = 'http://www.airnowapi.org/aq/forecast/latLong/?format=application/json';
  
  // inputing query parameter
  String forcUrl = forcBase + '&latitude=' + lat.toString() + '&longitude=' + long.toString() + '&distance=25&API_KEY=5193A560-1A7C-4A65-9B31-AEB3D235BB4F';

  Response response = await get(forcUrl);
  
  // the status of the get request
  int statusCode = response.statusCode;
  
  // if the request passes
  if (statusCode == 200){
    var currBody = json.decode(response.body);
    
    // check if an emepty array was returned 
    if(currBody.length == 0){
      return null;
    }
   for(Map day in currBody){
      // creates a city object from the request
      cityAQI city = new cityAQI.fromJson(day);
      city.date = day['DateForecast'];
      forecastList.add(city);
    }
    return forecastList; 
  }
  return null;
}

class ForecastData {
  ForecastData(this.day, this.aqi);
  final String day;
  final int aqi;
}

List closestLatLong(double lat1, double lon1, var cityToCoor){
    double minDist = double.maxFinite;
    List pair = [];
    var p = 0.017453292519943295;
    var c = cos;
    void iterateMapEntry(key, value) {
      double lat2 = value[0];
      double lon2 = value[1];
      var a = 0.5 - c((lat2 - lat1) * p)/2 + 
      c(lat1 * p) * c(lat2 * p) * 
      (1 - c((lon2 - lon1) * p))/2;
      double dist =  12742 * asin(sqrt(a));
     
      if(dist < minDist){
        pair = value;
        minDist = dist;
      }
    }
    cityToCoor.forEach(iterateMapEntry);
    return pair;
  }


// The following function reads the document line by line and maps city names to thier respective coordinates. 
Map<dynamic, dynamic> processLines(List<String> lines) {
  // process lines:
  var cityToCoor = Map();
  // for each line in the file we map the city in this line to its [lat, long] pair
  for (var line in lines) {
    // split the line by commas
    List listLine = line.split(',');
    List latLong = [ double.parse(listLine[3]), double.parse(listLine[4])];
    cityToCoor[listLine[0].toString()] = latLong;
  }
  return cityToCoor;
}
//------------------------------------------------- MAIN -------------------------------------------------------



void main() async {
  var location = new Location();
  Map<String, double> currentLocation;
  currentLocation = await location.getLocation();
  //writeContent('LOLOL');

  // "/Documents/aqiapp/cities.csv" contains all cities and associtaed lat, longs and postal codes
  File data = new File("/Documents/aqiapp/cities.csv");
  // a map to city name to [lat, long] pairs
  var cityToCoor = await data.readAsLines().then(processLines);
  List latlong = closestLatLong(currentLocation['latitude'], currentLocation['longitude'], cityToCoor);
  double lat;
  double long; 
  
  // NEAREST LOCATION
  if(false){
    lat = latlong[0];
    long = latlong[1];
  } else {
    // for searching city 
  String city = 'Seattle-Bellevue-Kent Valley';
    // checks if our city exists 
    if(cityToCoor.containsKey(city)){
      List pair = cityToCoor[city];
      lat = pair[0];
      long = pair[1];  
    }
  }
  cityAQI val = await _makeGetRequest(lat, long);
  List forecast = await _forecast(lat, long);
  globals.currCity = val;
  globals.currForecast = forecast;
  runApp(MyApp());
}
 // ------------------------------------------------ WIDGETS -----------------------------------------------------
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: new MyHomePage());
  }
}

class MyHomePage extends StatefulWidget {
  @override 
  _MyHomePage createState() => _MyHomePage();
}

class _MyHomePage extends State<MyHomePage> {
  final dbHelper = DatabaseHelper.instance;
  String city = globals.currCity.city;
  String state = globals.currCity.state;
  int aqi = globals.currCity.aqi;
  static String catName = globals.currCity.catName;
  int catNum = globals.currCity.catNum;
  String actions = globals.advice[catName];
  static String primPoll = globals.currCity.primPollutant;
  String pollConc = globals.currCity.pollConc[primPoll].toString();
  String units = globals.units[primPoll];
  getForecast(List<dynamic> days)
  {
    List<int> list = new List<int>();

    if (days == null){
      list.add(-1);
      return list;
    }
    for(var i = 0; i < days.length; i++){
      if(days[i].aqi != -1){
        list.add(days[i].aqi);
      }
    }
    if(list.length == 0){
      list.add(-1);
    }
      return list;
  }

  Widget pollConcentrations()
  {
    List<Widget> list = new List<Widget>();
    globals.currCity.pollConc.forEach((k,v) => list.add(new Text(k + ': ' + v.toString() + ' ' + globals.units[k])));

    if(list.length == 0){
      list.add(new Text('No pollutant information availible'));
    }
      return new ListBody(children: list);
  }
  @override 
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            centerTitle: true,
            title: Text("Air Quality Index",
                style: TextStyle(
                    fontSize: 36,
                    fontFamily: 'Noto Sans',
                    letterSpacing: 3,
                    fontWeight: FontWeight.bold)),
            backgroundColor: Colors.blue[100],
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20))),
        body: _returnNewCity());
  }
  _returnNewCity() {
    return Container(
        child: SingleChildScrollView(
            child: Center(
      child:
          Column(mainAxisAlignment: MainAxisAlignment.start, children: <Widget>[
        Container(
          padding: EdgeInsets.fromLTRB(5, 10, 5, 0),
          child: Text(
            city + ", " + state,
            style: TextStyle(
                fontSize: 36,
                fontFamily: 'Noto Sans',
                letterSpacing: 3,
                fontWeight: FontWeight.bold),
          ),
        ),
        Stack(alignment: Alignment.center, children: <Widget>[
          Container(
            alignment: Alignment.bottomCenter,
            padding: EdgeInsets.fromLTRB(5, 0, 5, 0),
            child: Text('\n'+(aqi).toString(),
                style: TextStyle(
                    fontSize: 36.0,
                    color: Colors.black54,
                    fontFamily: 'Noto Sans',
                    letterSpacing: 3,
                    fontWeight: FontWeight.bold)),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(5, 0, 5, 0),
            child: new AnimatedCircularChart(
              key: _chartKey,
              size: const Size(275.0, 275.0),
              initialChartData: <CircularStackEntry>[
                new CircularStackEntry(
                  <CircularSegmentEntry>[
                    new CircularSegmentEntry((aqi + 0.0)/500.0, Colors.lightGreen),
                    new CircularSegmentEntry((500.0 - aqi)/500.0, Colors.brown[50])
                  ],
                )
              ],
              chartType: CircularChartType.Radial,
              startAngle: 120.0,
              edgeStyle: SegmentEdgeStyle.round,
              percentageValues: true,
              holeLabel: catName + '\n',
              labelStyle: new TextStyle(
                  color: Colors.lightGreen[200],
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                  fontSize: 48.0),
            ),
          ),
        ]),
        Container(
          padding: EdgeInsets.fromLTRB(14, 1, 14, 1),
          child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text("Primary Pollutant",
                    style: TextStyle(
                        color: Colors.black54,
                        fontSize: 16,
                        fontFamily: 'Noto Sans',
                        fontWeight: FontWeight.bold)),
                Text(primPoll,
                    style: TextStyle(
                        color: Colors.black38,
                        fontSize: 14,
                        fontFamily: 'Noto Sans'))
              ]),
        ),
        Container(
            padding: EdgeInsets.fromLTRB(14, 1, 14, 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text("Concentration",
                    style: TextStyle(
                        color: Colors.black54,
                        fontSize: 16,
                        fontFamily: 'Noto Sans',
                        fontWeight: FontWeight.bold)),
                Text(pollConc + units,
                    style: TextStyle(
                        color: Colors.black38,
                        fontSize: 14,
                        fontFamily: 'Noto Sans'))
              ],
            )),
        Container(
            padding: EdgeInsets.fromLTRB(14, 1, 14, 1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text("Category Number",
                    style: TextStyle(
                        color: Colors.black54,
                        fontSize: 16,
                        fontFamily: 'Noto Sans',
                        fontWeight: FontWeight.bold)),
                Text((catNum).toString(),
                    style: TextStyle(
                        color: Colors.black38,
                        fontSize: 14,
                        fontFamily: 'Noto Sans'))
              ],
            )),
        _forecasts(getForecast(globals.currForecast))
      ]),
    )));
  }
  _findMin(List<int> list) {
    int min = list.elementAt(0);
    for (var i = 0; i < list.length; i++) {
      if (min > list.elementAt(i))
        min = list.elementAt(i);
    }
    return min;
  }

  _findMax(List<int> list) {
    int max = list.elementAt(0);
    for (var i = 0; i < list.length; i++) {
      if (max < list.elementAt(i))
        max = list.elementAt(i);
    }
    return max;
  }

  _getList() {
    List<int> list = new List<int>();
    list.add(101);
    list.add(52);
    list.add(33);
    list.add(46);
    return list;
  }

  _getDay(int day) {
    if (day == 1)
      return "Mon";
    if (day == 2)
      return "Tues";
    if (day == 3)
      return "Wed";
    if (day == 4)
      return "Thurs";
    if (day == 5)
      return "Fri";
    if (day == 6)
      return "Sat";
    if (day == 0)
      return "Sun";
  }

  _getFirstDay(String date){
    int i = 0;
    String curr = "";
    for (; i < 4; i++)
      curr += date[i];
    int year = int.parse(curr);
    curr = "";
    i++;
    for (; i < 7; i++)
      curr += date[i];
    int month = int.parse(curr);
    curr = "";
    i++;
    for (; i < 10; i++)
      curr += date[i];
    int day = int.parse(curr);
    var firstDay = new DateTime(year, month, day);
    return firstDay.weekday;
  }

  _getDataSeries(List<int> aqiList, int firstDay) {
    List<ForecastData> list = new List<ForecastData>();
    for (var i = 0; i < aqiList.length; i++) {
      list.add(new ForecastData(_getDay((firstDay+i)%7), aqiList.elementAt(i)));
    }
    return list;
  }

  _forecasts(String date) {
    List <int> list = _getList();
    int firstDay = _getFirstDay(date);
    List<ForecastData> myForecasts = _getDataSeries(list, firstDay+1);
    if (list.elementAt(0) == -1) {
      return Container(
          padding: EdgeInsets.fromLTRB(5, 10, 5, 0),
          child: Text(
            "The forecast is currently not available",
            style: TextStyle(
                fontSize: 36,
                fontFamily: 'Noto Sans',
                letterSpacing: 3,
                fontWeight: FontWeight.bold),
          ),
        );
    }
    return Container(
        height: 250,
        width: 400,
        padding: EdgeInsets.fromLTRB(7, 0, 7, 5),
        child: SfCartesianChart(
            primaryXAxis: CategoryAxis(interval: 1),
            primaryYAxis: NumericAxis(minimum: _findMin(list)-10.0, maximum: _findMax(list)+10.0),
            title: ChartTitle(text: "AQI Weekly Forecast"),
            legend: Legend(isVisible: false),
            series: <ChartSeries>[
              SplineSeries<ForecastData, String>(
                  dataSource: myForecasts,
                  xValueMapper: (ForecastData fore, _) => fore.day,
                  yValueMapper: (ForecastData fore, _) => fore.aqi,
                  enableTooltip: true)
            ]));
  }
}
