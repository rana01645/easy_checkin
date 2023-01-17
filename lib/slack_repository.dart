import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:ui';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;

import 'package:background_locator_2/location_dto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'file_manager.dart';

class SlackRepository {
  static SlackRepository _instance = SlackRepository._();

  SlackRepository._();

  factory SlackRepository() {
    return _instance;
  }

  //is signed in today
  Future<bool> isSignedIn() async {
    print('inside isSignedIn');
    final prefs = await SharedPreferences.getInstance();
    //save to shared pref
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

  //set remote status
  Future<void> setRemoteStatus() async {
    //save to shared pref
    final prefs = await SharedPreferences.getInstance();
    //today as string
    String today = getDate();
    //save the signin time
    prefs.setBool('remote-status-$today', true);
  }

  //is set remote status
  Future<bool> isSetRemote() async {
    final prefs = await SharedPreferences.getInstance();
    String today = getDate();
    var remote = prefs.getBool('remote-status-$today') ?? false;
    return remote;
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

  String getDate() {
    DateTime dateToday = DateTime.now();
    String today = dateToday.toString().substring(0, 10);
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
      prefs.remove('remote-status-$today');
    });
  }

  //clear login
  Future<void> logout() async {
    clearTodaysLog();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('slack_key', '');
    await prefs.setString('channel_name', '');
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

  Future<String> getSlackKey() async {
    final prefs = await SharedPreferences.getInstance();
    var slackKey = prefs.getString('slack_key') ?? '';
    return slackKey;
  }
}
