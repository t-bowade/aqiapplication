library my_prj.globals;
import 'package:aqiapp/main.dart';

cityAQI currCity;
List currForecast;
var units = {
'PM2.5': 'ug/m3', 
'PM10': 'ug/m3',
'CO': 'ppm',
'O3': 'ppm',
'SO2': 'ppb',
'NO2': 'ppb',
};
String whatIsAQI = "The EPA developed the AQI, which reports levels of ozone, particle pollution, and other common air pollutants on the same scale. An AQI reading of 101 corresponds to a level above the national air quality standard - the higher the AQI rating, the greater the health impact.";
var advice = {
'Good': 'Air pollution poses little or no risk.', 
'Moderate': 'Air quality is acceptable; however, pollution in this range may pose a moderate health concern for a very small number of individuals. People who are unusually sensitive to ozone or particle pollution may experience respiratory symptoms.',
'Unhealthy for Sensitive Groups': 'Members of sensitive groups may experience health effects, but the general public is unlikely to be affected',
'Unhealthy': 'Everyone may begin to experience health effects; members of sensitive groups may experience more serious health effects',
'Very Unhealthy': 'Health alert: everyone may experience more serious health effects.',
'Hazerdous': 'Health warnings of emergency conditions. The entire population is more likely to be affected.',
};
