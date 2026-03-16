import 'package:flutter/material.dart';
import 'screens/overview_screen.dart';
import 'screens/map_screen.dart';
import 'screens/channel_scan_screen.dart';
import 'package:provider/provider.dart';
import 'providers/tracker_provider.dart';
import 'screens/terminal_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => TrackerProvider(),
      child: SimpleTrackerApp(),
    ),
  );
}

class SimpleTrackerApp extends StatelessWidget {
  const SimpleTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SimpleTracker',
      theme: ThemeData.dark(),
      debugShowCheckedModeBanner: false,
      home: DefaultTabController(
        length: 4, // Number of tabs
        child: MyHomePage(),
      ),
    );
  }
}


class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  MyHomePageState createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('SimpleTracker'),
        bottom: TabBar(
          tabs: [
            Tab(icon: Icon(Icons.home), text: "Overview"),
            Tab(icon: Icon(Icons.map), text: "Map"),
            Tab(icon: Icon(Icons.radar), text: "Channel Scan"),
            Tab(icon: Icon(Icons.text_fields_rounded), text: "Serial Connection"),
            //Tab(icon: Icon(Icons.settings), text: "Settings"),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          OverviewScreen(),
          MapScreen(),
          ChannelScanScreen(),
          TerminalScreen(),
          //SettingPage(),
        ],
      ),
    );
  }
}
