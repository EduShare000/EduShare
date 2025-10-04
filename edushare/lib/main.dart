import 'package:flutter/material.dart';
import 'screens/authScreen.dart';
import 'screens/decisionScreen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Edushare',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.grey,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginPage(),
        '/decision': (context) => const DecisionScreen(),
      },
    );
  }
}
