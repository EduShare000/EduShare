import 'package:flutter/material.dart';
import 'screens/requester.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    UserCredential userCredential = await FirebaseAuth.instance.signInAnonymously();
    print("Signed in anonymously with UID: ${userCredential.user?.uid}");

    runApp(const Requester());
  } catch (e) {
    print("Error initializing Firebase: $e");
    runApp(const ErrorApp());
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