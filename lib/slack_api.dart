import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:ui';
import 'package:easy_checkin/slack_repository.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;

import 'package:background_locator_2/location_dto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'file_manager.dart';

class SlackApi {
  static SlackApi _instance = SlackApi._();

  SlackApi._();

  factory SlackApi() {
    return _instance;
  }

  //send data to slack
  Future<void> signingInToSlack({bool silent = false}) async {
    //check if signed in today
    if (await SlackRepository().isSignedIn()) {
      if (!silent) {
        Fluttertoast.showToast(msg: "Already signed in today");
      }
      return;
    }

    //slack api call
    final response = await sendMessageToSlack('Signing In');
    //convert to json
    var json = jsonDecode(response.body);
    if (json['ok'] == true) {
      //signed in
      await SlackRepository().signIn(json['ts']);
      if(!silent){
        Fluttertoast.showToast(msg: "Signed in successfully");
      }
    } else {
      if (!silent) {
        Fluttertoast.showToast(msg: 'Unable to sign in, check your key!');
      }
    }
  }

    //send data to slack
  Future<void> signingInToSlackRemotely() async {
    //check if signed in today
    if (await SlackRepository().isSignedIn()) {
      Fluttertoast.showToast(msg: "Already signed in today");
      return;
    }

    //slack api call
    final response = await sendMessageToSlack('Signing In Remotely');
    //convert to json
    var json = jsonDecode(response.body);
    if (json['ok'] == true) {
      //signed in
      await SlackRepository().signIn(json['ts']);
      var statusResponse = await setStatusOnSlack('Working remotely', ':house_with_garden:');
      var statusJson = jsonDecode(statusResponse.body);
      if (statusJson['ok'] == true) {
        SlackRepository().setRemoteStatus();
        Fluttertoast.showToast(msg: "Set status working remotely successfully");
      } else {
        Fluttertoast.showToast(msg: 'Unable to sign in remotely, check your key!');
      }
      Fluttertoast.showToast(msg: "Signed in successfully");
    } else {
      Fluttertoast.showToast(msg: 'Unable to sign in, check your key!');
    }
  }

  Future<void> sendBRB() async {
    //check if signed in today
    if (await SlackRepository().isSignedOut()) {
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

    Future<void> isBackToWork() async {
    //check if signed in today
    if (await SlackRepository().isSignedOut()) {
      Fluttertoast.showToast(msg: "Already signed out today, cannot send other message");
      return;
    }

    //slack api call
    final response = await sendMessageToSlack(':back:');
    //convert to json
    var json = jsonDecode(response.body);
    if (json['ok'] == true) {
      //signed in
      Fluttertoast.showToast(msg: "Sent Back successfully");
    } else {
      Fluttertoast.showToast(msg: 'Unable to send Back, check your key!');
    }
  }

  Future<void> signingOutFromSlack({bool silent = false}) async {
    //check if signed in today
    if (await SlackRepository().isSignedOut()) {
      if (!silent) {
        Fluttertoast.showToast(msg: "Already signed out today");
      }
      return;
    }
    final response = await sendMessageToSlack('Signing Out');

    //convert to json
    var json = jsonDecode(response.body);
    if (json['ok'] == true) {
      //signed in
      await SlackRepository().signOut();
      if (await SlackRepository().isSetRemote()) {
        setStatusOnSlack("", "");
      }
      if (!silent) {
        Fluttertoast.showToast(msg: "Signed out successfully");
      }
    } else {
      if (!silent) {
        Fluttertoast.showToast(msg: 'Unable to sign out, check your key!');
      }
    }
  }

  Future<http.Response> sendMessageToSlack(String message) async {
    //get the slack key from shared pref
    var slackKey = await SlackRepository().getSlackKey();
    print(slackKey);

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
        'thread_ts': await SlackRepository().getThreadTs()
      }),
    );
    print(response.body);

    return response;
  }

  Future<http.Response> setStatusOnSlack(String status,String emoji) async {
    //get the slack key from shared pref
    var slackKey = await SlackRepository().getSlackKey();
    print(slackKey);

    var bearer = 'Bearer $slackKey';
    final response = await http.post(
      Uri.parse('https://slack.com/api/users.profile.set'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': bearer,
      },
      body: jsonEncode(<String, String>{
        'profile': '{"status_text": "$status", "status_emoji": "$emoji", "status_expiration": 0}',
      }),
    );
    print(response.body);

    return response;
  }
}
