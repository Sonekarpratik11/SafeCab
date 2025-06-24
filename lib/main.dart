import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:safe_cab_user/auth/phone_screen.dart';
import 'package:safe_cab_user/splashScreen/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  static void restartApp(BuildContext context) {
    final state = context.findAncestorStateOfType<_MyAppState>();
    state?.restartApp();
  }

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  UniqueKey key = UniqueKey();

  void restartApp() {
    setState(() {
      key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Safe Cab',
        theme: ThemeData(primarySwatch: Colors.blue),
        initialRoute: '/',
        routes: {
          '/': (context) => const MySplashScreen(),
          '/phone': (context) => const PhoneScreen(),
        },
      ),
    );
  }
}
