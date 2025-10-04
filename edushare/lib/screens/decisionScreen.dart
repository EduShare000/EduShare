import 'package:flutter/material.dart';

class DecisionScreen extends StatelessWidget {
  const DecisionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                // TODO: Navigate to Request Page
              },
              child: Container(
                color: Colors.cyanAccent,
                child: const Center(
                  child: Text(
                    "Request",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                // TODO: Navigate to Donate Page
              },
              child: Container(
                color: Colors.green,
                child: const Center(
                  child: Text(
                    "Donate",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
