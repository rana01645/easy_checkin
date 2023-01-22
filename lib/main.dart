import 'dart:async';
import 'package:easy_checkin/slack_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app/module/views/login_app.dart';
import 'app/module/views/main_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var channelName = await SlackRepository().getChannelName();
  var slackKey = await SlackRepository().getSlackKey();
  var isLoggedIn = channelName.isNotEmpty && slackKey.isNotEmpty;
  await dotenv.load(fileName: ".env"); //path to your .env file);

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: isLoggedIn ? MyApp() : const LoginApp(),
  ));
}
