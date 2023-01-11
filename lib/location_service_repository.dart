import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
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
    double distance = calculateDistance(
        23.8371806, 90.3683082, locationDto.latitude, locationDto.longitude);
    //if distance is less than 500 meter then print at office
    if (distance < 0.5) {
      print("At Office ${distance.toStringAsFixed(2)}");
    } else {
      print("Not At Office ${distance.toStringAsFixed(2)}");
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

  Future<void> saveName(String text) async {
    //save to shared pref
    final prefs = await SharedPreferences.getInstance();

    // Save an String value to 'action' key.
    await prefs.setString('name', text);
  }

  Future<void> saveSlackKey(String text) async {
    //save to shared pref
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('slack_key', text);
  }

    //is signed in today
  Future<bool> isSignedIn() async {
    print('inside isSignedIn');
    //save to shared pref
    final prefs = await SharedPreferences.getInstance();
    String today = getDate();
    var signed = prefs.getBool('signed-in-$today') ?? false;
    print('signed-in-$today : $signed');
    return signed;
  }

  Future<void> signIn(String ts) async {
    //save to shared pref
    final prefs = await SharedPreferences.getInstance();
    //today as string
    String today = getDate();
    //save the signin time
    prefs.setString('sign-in-time-$today', getTime());
    prefs.setBool('signed-in-$today', true);
    prefs.setString('sign-in-ts-$today', ts);

  }

    //is signed in today
  Future<bool> isSignedOut() async {
    //save to shared pref
    final prefs = await SharedPreferences.getInstance();
    //todays date as string
    String today = getDate();
    return prefs.getBool('signed-out-$today') ?? false;
  }

  Future<void> signOut() async {
    //save to shared pref
    final prefs = await SharedPreferences.getInstance();
    //today as string
    String today = getDate();

    print(today);
    //save the signin time
    await prefs.setString('sign-out-time-$today', getTime());
    await prefs.setBool('signed-out-$today', true);
  }


  String getDate(){
    DateTime dateToday = DateTime.now();
    String today = dateToday.toString().substring(0,10);
    return today;
  }

  String getTime() {
    DateTime dateToday = DateTime.now();
    return dateToday.toIso8601String();
  }

  //get thread ts getThreadTs
  Future<String> getThreadTs() async {
    //save to shared pref
    final prefs = await SharedPreferences.getInstance();
    //todays date as string

    String today = getDate();
    String signed = prefs.getString('sign-in-ts-$today') ?? '';
    return signed;
  }



  //send data to slack
  Future<void> signingInToSlack(name, slackkey) async {
    //check if signed in today
    if (await isSignedIn()) {
      Fluttertoast.showToast(msg: "Already signed in today");
      return;
    }

    //slack api call
    final response = await sendMessageToSlack('Signing In');
    //convert to json
    var json = jsonDecode(response.body);
    if (json['ok'] == true) {
      //signed in
      await signIn(json['ts']);
      Fluttertoast.showToast(msg: "Signed in successfully");
    } else {
      Fluttertoast.showToast(msg: 'Unable to sign in, check your key!');
    }
  }

  Future<void> sendBRB(name, slackkey) async {
    //check if signed in today
    if (await isSignedOut()) {
      Fluttertoast.showToast(msg: "Already signed out today, cannot send other message");
      return;
    }

    //slack api call
    final response = await sendMessageToSlack(':BRB:');
    //convert to json
    var json = jsonDecode(response.body);
    if (json['ok'] == true) {
      //signed in
      Fluttertoast.showToast(msg: "Sent BRB successfully");
    } else {
      Fluttertoast.showToast(msg: 'Unable to send BRB, check your key!');
    }
  }

  Future<void> signingOutFromSlack(name, slackkey) async {
    //check if signed in today
    if (await isSignedOut()) {
      Fluttertoast.showToast(msg: "Already signed out today");
      return;
    }
    final response = await sendMessageToSlack('Signing Out');

    //convert to json
    var json = jsonDecode(response.body);
    if (json['ok'] == true) {
      //signed in
      signOut();
      Fluttertoast.showToast(msg: "Signed out successfully");
    } else {
      Fluttertoast.showToast(msg: 'Unable to sign out, check your key!');
    }
  }

  Future<http.Response> sendMessageToSlack(String message) async {
    //get the slack key from shared pref
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    var slackKey = prefs.getString('slack_key') ?? '';

    var bearer = 'Bearer $slackKey';
    final response = await http.post(
      Uri.parse('https://slack.com/api/chat.postMessage'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': bearer,
      },
      body: jsonEncode(<String, String>{
        'channel': 'rana_checkin',
        'text': message,
        'thread_ts': await getThreadTs()
      }),
    );

    return response;
  }

  void clearTodaysLog() {
    //save to shared pref
    SharedPreferences.getInstance().then((prefs) {
      String today = getDate();
      String time = getTime();
      prefs.remove('sign-in-time-$time');
      prefs.remove('signed-in-$today');
      prefs.remove('sign-in-ts-$today');
      prefs.remove('sign-out-time-$time');
      prefs.remove('signed-out-$today');
    });
  }
}
