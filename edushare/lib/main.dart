import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/requester.dart' as requester_screen;
import 'screens/donator.dart' as donator_screen;
import 'screens/login_page.dart';
import 'app_navigator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const AppShell());
  } catch (e) {
    print("Error initializing Firebase: $e");
    runApp(const ErrorApp());
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // 0 = Requester, 1 = Donator
  int _selectedIndex = 0;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      setState(() {
        _isLoggedIn = user != null;
      });
    });
  }

  void _select(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF1C1C1E),
      cardColor: const Color(0xFF2C2C2E),
      colorScheme: ColorScheme.dark(
        primary: Colors.cyanAccent[400]!,
        secondary: Colors.cyanAccent[400]!,
        surface: const Color(0xFF1C1C1E),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1C1C1E),
        elevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );

    Widget body;
    String title;
    if (_selectedIndex == 0) {
      body = const requester_screen.RequesterHomePage();
      title = 'Requester';
    } else {
      body = const donator_screen.DonatorHomePage();
      title = 'Donator';
    }

    return MaterialApp(
      title: 'EduShare',
      navigatorKey: appNavigatorKey,
      theme: theme,
      home: _isLoggedIn 
          ? Scaffold(
              appBar: AppBar(
                title: Text('EduShare - $title'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: () {
                      FirebaseAuth.instance.signOut();
                    },
                  ),
                ],
              ),
              drawer: Drawer(
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DrawerHeader(
                        decoration: const BoxDecoration(
                          color: Color(0xFF111111),
                        ),
                        child: Center(
                          child: Text('EduShare',
                              style: Theme.of(context).textTheme.titleLarge),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.list),
                        title: const Text('Requester - Find items'),
                        selected: _selectedIndex == 0,
                        onTap: () {
                          appNavigatorKey.currentState?.pop();
                          _select(0);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.add_box),
                        title: const Text('Donator - Create listings'),
                        selected: _selectedIndex == 1,
                        onTap: () {
                          appNavigatorKey.currentState?.pop();
                          _select(1);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              body: body,
            )
          : const LoginPage(),
    );
  }
}

class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Failed to initialize Firebase',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Please check your configuration and try again.'),
            ],
          ),
        ),
      ),
    );
  }
}