import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:background_locator_2/background_locator.dart';
import 'package:background_locator_2/location_dto.dart';
import 'package:background_locator_2/settings/android_settings.dart';
import 'package:background_locator_2/settings/ios_settings.dart';
import 'package:background_locator_2/settings/locator_settings.dart';
import 'package:easy_checkin/slack_api.dart';
import 'package:easy_checkin/slack_repository.dart';
import 'package:flutter/material.dart';
import 'package:location_permissions/location_permissions.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'file_manager.dart';
import 'location_callback_handler.dart';
import 'location_service_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var channelName = await LocationServiceRepository().getChannelName();
  var slackKey = await SlackRepository().getSlackKey();
  var isLoggedIn = channelName.isNotEmpty && slackKey.isNotEmpty;

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: isLoggedIn ? MyApp() : const LoginApp(),
  ));
}

//add login app using channel_name and slack api key
class LoginApp extends StatefulWidget {
  const LoginApp({super.key});

  @override
  _LoginAppState createState() => _LoginAppState();
}

class _LoginAppState extends State<LoginApp> {
  final _formKey = GlobalKey<FormState>();
  final _channelNameController = TextEditingController();
  final _slackKeyController = TextEditingController();

  @override
  void initState() {
    // TODO: implement initState
    fillData();
    super.initState();
  }

  Future<void> fillData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    var name = prefs.getString('name') ?? '';
    var slackKey = prefs.getString('slack_key') ?? '';
    _channelNameController.text = name;
    _slackKeyController.text = slackKey;
  }

  @override
  void dispose() {
    _channelNameController.dispose();
    _slackKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Login'),
        ),
        body: Container(
          padding: const EdgeInsets.all(22),
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextFormField(
                controller: _channelNameController,
                decoration: InputDecoration(
                  hintText: 'Enter Channel name',
                ),
              ),
              TextFormField(
                controller: _slackKeyController,
                decoration: InputDecoration(
                  hintText: 'Enter your slack api key',
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: ElevatedButton(
                  onPressed: () {
                    //save name and slack api key to shared preferences and start location service
                    LocationServiceRepository().saveChannelName(_channelNameController.text);
                    LocationServiceRepository()
                        .saveSlackKey(_slackKeyController.text);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => MyApp()));
                  },
                  child: Text('Submit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatefulWidget {

  MyApp({Key? key})
      : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ReceivePort port = ReceivePort();

  final _range = TextEditingController();

  String logStr = '';
  bool isRunning = false;
  LocationDto? lastLocation;

  @override
  void initState() {
    super.initState();

    if (IsolateNameServer.lookupPortByName(
            LocationServiceRepository.isolateName) !=
        null) {
      IsolateNameServer.removePortNameMapping(
          LocationServiceRepository.isolateName);
    }

    IsolateNameServer.registerPortWithName(
        port.sendPort, LocationServiceRepository.isolateName);

    LocationServiceRepository()
        .getRange()
        .then((value) => _range.text = value.toString());

    port.listen(
      (dynamic data) async {
        await updateUI(data);
      },
    );
    initPlatformState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> updateUI(LocationDto data) async {
    final log = await FileManager.readLogFile();

    await _updateNotificationText(data);

    setState(() {
      if (data != null) {
        lastLocation = data;
      }
      logStr = log;
    });
  }

  Future<void> _updateNotificationText(LocationDto data) async {
    if (data == null) {
      return;
    }

    bool atOffice = await LocationServiceRepository().isAtOffice(data);
    String notificationText = atOffice ? 'Currently At Office' : 'Not At Office';

    final _isRunning = await BackgroundLocator.isServiceRunning();

    String title = _isRunning ? 'Easy Checking (Running)' : 'Easy Check-in '
        '(Stopped)';

    await BackgroundLocator.updateNotificationText(
        title: title,
        msg: notificationText,
        bigMsg: notificationText);
  }

  Future<void> initPlatformState() async {
    print('Initializing...');
    await BackgroundLocator.initialize();
    logStr = await FileManager.readLogFile();
    print('Initialization done');
    final _isRunning = await BackgroundLocator.isServiceRunning();
    setState(() {
      isRunning = _isRunning;
    });
    print('Running ${isRunning.toString()}');
  }

  @override
  Widget build(BuildContext context) {
    final start = SizedBox(
      width: double.maxFinite,
      child: ElevatedButton(
        child: Text('Start Signing in Based on Location'),
        onPressed: () {
          _onStart();
        },
      ),
    );

    final signinging = SizedBox(
      width: double.maxFinite,
      child: ElevatedButton(
        style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all(Colors.green)),
        child: Text('Signing in to slack'),
        onPressed: () {
          _signignIn();
        },
      ),
    );

    final remotely = SizedBox(
      width: double.maxFinite,
      child: ElevatedButton(
        style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all(Colors.green)),
        child: Text('Signing in remotely to slack'),
        onPressed: () {
          _signignInRemotely();
        },
      ),
    );

    final brb = SizedBox(
      width: double.maxFinite,
      child: ElevatedButton(
        child: Text('BRB'),
        onPressed: () {
          _brb();
        },
      ),
    );

    final back = SizedBox(
      width: double.maxFinite,
      child: ElevatedButton(
        child: Text('Back To Work'),
        onPressed: () {
          _btw();
        },
      ),
    );

    final signingOut = SizedBox(
      width: double.maxFinite,
      child: ElevatedButton(
        style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all(Colors.redAccent)),
        child: Text('Signing out'),
        onPressed: () {
          _signignOut();
        },
      ),
    );
    final stop = SizedBox(
      width: double.maxFinite,
      child: ElevatedButton(
        child: Text('Take a break'),
        onPressed: () {
          onStop();
        },
      ),
    );
    final clear = SizedBox(
      width: double.maxFinite,
      child: ElevatedButton(
        child: const Text('Clear Todays Log(Locally)'),
        onPressed: () {
          clearLog();
        },
      ),
    );
    String msgStatus = "-";
    if (isRunning != null) {
      if (isRunning) {
        msgStatus = 'Running';
      } else {
        msgStatus = 'Stopped';
      }
    }
    final status = Text("Location Check Status: $msgStatus");

    final log = Text(
      logStr,
    );

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Easy Check-in'),
        ),
        body: Container(
          width: double.maxFinite,
          padding: const EdgeInsets.all(22),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const Padding(
                          padding: EdgeInsets.all(5.0),
                          child: Text(
                            'Slack Easy Checkin!',
                            textAlign: TextAlign.left,
                            style: TextStyle(fontSize: 20),
                          )),
                      signinging,
                      remotely,
                      brb,
                      back,
                      signingOut,
                      clear,
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const Padding(
                          padding: EdgeInsets.all(5.0),
                          child: Text(
                            'Automation!',
                            textAlign: TextAlign.left,
                            style: TextStyle(fontSize: 20),
                          )),
                      const Text('Enter the range from office in Meter',
                          textAlign: TextAlign.left),
                      TextFormField(
                        keyboardType: TextInputType.number,
                        controller: _range,
                        decoration: const InputDecoration(
                          hintText: 'Enter the range from office in meter',
                        ),
                      ),
                      //text input
                      start,
                      stop,
                      status,
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  void onStop() async {
    await BackgroundLocator.unRegisterLocationUpdate();
    final _isRunning = await BackgroundLocator.isServiceRunning();
    setState(() {
      isRunning = _isRunning;
    });
  }

  void _onStart() async {
    _range.text = _range.text.isEmpty ? '100' : _range.text;
    LocationServiceRepository().setRange(_range.text);
    if (await _checkLocationPermission()) {
      await _startLocator();
      final _isRunning = await BackgroundLocator.isServiceRunning();

      setState(() {
        isRunning = _isRunning;
        lastLocation = null;
      });
    } else {
      // show error
    }
  }

  void _signignIn() async {
    SlackApi().signingInToSlack();
  }

  void _signignInRemotely() async {
    SlackApi().signingInToSlackRemotely();
  }

  void _brb() async {
    SlackApi().sendBRB();
  }

  void _btw() async {
    SlackApi().isBackToWork();
  }

  void _signignOut() async {
    SlackApi().signingOutFromSlack();
  }

  void clearLog() async {
    SlackRepository().clearTodaysLog();
  }

  Future<bool> _checkLocationPermission() async {
    final access = await LocationPermissions().checkPermissionStatus();
    switch (access) {
      case PermissionStatus.unknown:
      case PermissionStatus.denied:
      case PermissionStatus.restricted:
        final permission = await LocationPermissions().requestPermissions(
          permissionLevel: LocationPermissionLevel.locationAlways,
        );
        if (permission == PermissionStatus.granted) {
          return true;
        } else {
          return false;
        }
        break;
      case PermissionStatus.granted:
        return true;
        break;
      default:
        return false;
        break;
    }
  }

  Future<void> _startLocator() async {
    Map<String, dynamic> data = {'countInit': 1};
    return await BackgroundLocator.registerLocationUpdate(
        LocationCallbackHandler.callback,
        initCallback: LocationCallbackHandler.initCallback,
        initDataCallback: data,
        disposeCallback: LocationCallbackHandler.disposeCallback,
        iosSettings: const IOSSettings(
            accuracy: LocationAccuracy.NAVIGATION,
            distanceFilter: 0,
            stopWithTerminate: true),
        autoStop: false,
        androidSettings: const AndroidSettings(
            accuracy: LocationAccuracy.NAVIGATION,
            interval: 5,
            distanceFilter: 0,
            client: LocationClient.google,
            androidNotificationSettings: AndroidNotificationSettings(
                notificationChannelName: 'Location tracking',
                notificationTitle: 'Start Location Tracking',
                notificationMsg: 'Track location in background',
                notificationBigMsg:
                    'Background location is on to keep the app up-tp-date with your location. This is required for main features to work properly when the app is not running.',
                notificationIconColor: Colors.grey,
                notificationTapCallback:
                    LocationCallbackHandler.notificationCallback)));
  }
}
