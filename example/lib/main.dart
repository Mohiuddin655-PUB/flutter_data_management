import 'package:data_management/data_management.dart' show DM;
import 'package:flutter/material.dart'
    show
        WidgetsFlutterBinding,
        runApp,
        StatelessWidget,
        BuildContext,
        Widget,
        MaterialApp;
import 'package:in_app_database/in_app_database.dart' show InAppDatabase;

import 'advanced_test.dart' show RefsTestPage;
import 'delegates/cache.dart' show CacheDelegate;
import 'delegates/connectivity.dart' show ConnectivityDelegate;
import 'delegates/local_db.dart' show LocalDatabaseDelegate;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DM.i.configure(
    connectivity: ConnectivityDelegate(),
    cache: CacheDelegate(),
  );
  await InAppDatabase.init(delegate: LocalDatabaseDelegate());
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: RefsTestPage(),
    );
  }
}
