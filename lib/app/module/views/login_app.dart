import 'package:easy_checkin/slack_api.dart';
import 'package:easy_checkin/slack_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:slack_login_button/slack_login_button.dart';

import 'main_app.dart';

class LoginApp extends StatefulWidget {
  const LoginApp({super.key});

  @override
  _LoginAppState createState() => _LoginAppState();
}

class _LoginAppState extends State<LoginApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var clientId = dotenv.env['SLACK_CLIENT_ID'];
    var clientSecret = dotenv.env['SLACK_CLIENT_SECRET'];
    final scope = [
      'chat:write:user',
      'users.profile:write',
      'channels:read',
      'groups:read'
    ];
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Login'),
        ),
        body: Center(
          child: SlackLoginButton(
            clientId!,
            clientSecret!,
            scope,
            (token) {
              SlackRepository().saveSlackKey(token?.accessToken ?? '');
              //get all channels and show in dropdown
              SlackApi().getAllChannels().then((channels) {
                print(channels);
                //show the channels in dropdown
                if (channels.isNotEmpty) {
                  //save the channel name
                  showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text('Select Channel'),
                          content: DropdownButton<String>(
                            items: channels
                                    ?.map((e) => DropdownMenuItem<String>(
                                          value: e['name'],
                                          child: Text(e['name']),
                                        ))
                                    .toList() ??
                                [],
                            onChanged: (value) {
                              SlackRepository().saveChannelName(value ?? '');
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => MyApp()));
                            },
                          ),
                        );
                      });
                }
              });
              print(token?.accessToken);
            },
          ),
        ),
      ),
    );
  }
}
