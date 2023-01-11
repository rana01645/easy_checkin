import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:ui';
import 'package:easy_checkin/slack_api.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;

import 'package:background_locator_2/location_dto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'file_manager.dart';

class LocationServiceRepository {
  static LocationServiceRepository _instance = LocationServiceRepository._();

  LocationServiceRepository._();

  factory LocationServiceRepository() {
    return _instance;
  }

  static const String isolateName = 'LocatorIsolate';

  int _count = -1;

  Future<void> init(Map<dynamic, dynamic> params) async {
    //TODO change logs
    print("***********Init callback handler");
    if (params.containsKey('countInit')) {
      dynamic tmpCount = params['countInit'];
      if (tmpCount is double) {
        _count = tmpCount.toInt();
      } else if (tmpCount is String) {
        _count = int.parse(tmpCount);
      } else if (tmpCount is int) {
        _count = tmpCount;
      } else {
        _count = -2;
      }
    } else {
      _count = 0;
    }
    print("$_count");
    await setLogLabel("start");
    final SendPort? send = IsolateNameServer.lookupPortByName(isolateName);
    send?.send(null);
  }

  Future<void> dispose() async {
    print("***********Dispose callback handler");
    print("$_count");
    await setLogLabel("end");
    final SendPort? send = IsolateNameServer.lookupPortByName(isolateName);
    send?.send(null);
  }

  Future<void> callback(LocationDto locationDto) async {
    print('$_count location in dart: ${locationDto.toString()}');
    //print distance from 23.8371806,90.3683082

    if (await isAtOffice(locationDto)) {
      SlackApi().signingInToSlack(silent: true);
    } else {
      SlackApi().signingOutFromSlack(silent: true);
    }

    await setLogPosition(_count, locationDto);
    final SendPort? send = IsolateNameServer.lookupPortByName(isolateName);
    send?.send(locationDto);
    _count++;
  }

  double calculateDistance(lat1, lon1, lat2, lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  Future<bool> isAtOffice(locationDto) async {
    double distance = calculateDistance(
        23.8371806, 90.3683082, locationDto.latitude, locationDto.longitude);
    //if distance is less than 500 meter then print at office
    if (distance < await rangeInKm()) {
      print("At Office ${distance.toStringAsFixed(2)}");
      return true;
    } else {
      print("Not At Office ${distance.toStringAsFixed(2)}");
      return false;
    }
  }

  static Future<void> setLogLabel(String label) async {
    final date = DateTime.now();
    await FileManager.writeToLogFile(
        '------------\n$label: ${formatDateLog(date)}\n------------\n');
  }

  static Future<void> setLogPosition(int count, LocationDto data) async {
    final date = DateTime.now();
    await FileManager.writeToLogFile(
        '$count : ${formatDateLog(date)} --> ${formatLog(data)} --- isMocked: ${data.isMocked}\n');
  }

  static double dp(double val, int places) {
    num mod = pow(10.0, places);
    return ((val * mod).round().toDouble() / mod);
  }

  static String formatDateLog(DateTime date) {
    return "${date.hour}:${date.minute}:${date.second}";
  }

  static String formatLog(LocationDto locationDto) {
    return "${dp(locationDto.latitude, 4)} ${dp(locationDto.longitude, 4)}";
  }

  Future<void> saveChannelName(String text) async {
    //save to shared pref
    final prefs = await SharedPreferences.getInstance();

    // Save an String value to 'action' key.
    await prefs.setString('channel_name', text);
  }

  //get channel name from shared pref
  Future<String> getChannelName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('channel_name') ?? '';
  }

  Future<void> saveSlackKey(String text) async {
    //save to shared pref
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('slack_key', text);
  }




  Future<void> setRange(String text) async {
    final prefs = await SharedPreferences.getInstance();
    //parse to int
    double range = double.parse(text);
    prefs.setDouble('range', range);
  }

  Future<double> getRange() async {
    final prefs = await SharedPreferences.getInstance();
    //parse to int
    double range = prefs.getDouble('range') ?? 100;
    return range;
  }

  //the range is in meter, convert it to km
  Future<double> rangeInKm() async {
    double range = await getRange();
    return range / 1000;
  }
}
