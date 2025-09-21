import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() {
  runApp(const Requester());
}

class Requester extends StatelessWidget {
  const Requester({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduShare - Requester',
      theme: ThemeData(
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
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
          titleMedium: TextStyle(fontSize: 20.0, fontWeight: FontWeight.w600),
          titleSmall: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(fontSize: 16.0),
          bodyMedium: TextStyle(fontSize: 14.0, color: Colors.white70),
          labelLarge: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF3A3A3C),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          hintStyle: TextStyle(color: Colors.grey[500]),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.cyanAccent[400],
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.cyanAccent[400],
          foregroundColor: Colors.black,
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: const Color(0xFF2C2C2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(color: Colors.white),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class Request {
  String id;
  String userId;
  String title;
  String description;
  String contactInfo;
  String requestType;
  String status;

  Request({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.contactInfo,
    required this.requestType,
    this.status = 'Active',
  });
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'contactInfo': contactInfo,
      'requestType': requestType,
      'status': status,
    };
  }

  factory Request.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Request(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      contactInfo: data['contactInfo'] ?? '',
      requestType: data['requestType'] ?? 'Take',
      status: data['status'] ?? 'Active',
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  void _addRequest(Request newRequest) {
    // TODO: Add logic here to save to a database. (STUCK, I THOUGHT THIS WOULD DO IT)
    FirebaseFirestore.instance.collection('requests').add(newRequest.toJson());
  }

  void _updateRequestStatus(String docId, String newStatus) {
    // 🔥 TODO: Add logic here to update the database. (STUCK, I THOUGHT THIS WOULD DO IT)
    FirebaseFirestore.instance
        .collection('requests')
        .doc(docId)
        .update({'status': newStatus});
  }

  Widget _buildStatusChip(String status) {
    Color color;
    if (status == 'Active') {
      color = Colors.greenAccent[400]!;
    } else {
      color = Colors.orange[400]!;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProfilePage(user: currentUser),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 TODO: Replace with database user profile name (STUCK, I THOUGHT THIS WOULD DO IT)
    String profileName = currentUser?.uid ?? "Guest User";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Your Postings"),
        actions: [
          TextButton.icon(
            onPressed: _openProfile,
            icon: const Icon(Icons.account_circle, color: Colors.white),
            label: Text(
              profileName,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('requests')
            .where('userId', isEqualTo: currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    "You haven't requested anything yet",
                    style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          final requests = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final requestDoc = requests[index];
              final request = Request.fromFirestore(requestDoc);
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.title,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          request.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                        const Divider(height: 24, color: Colors.white12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatusChip(request.status),
                            Text(
                              "Type: ${request.requestType}",
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 13,
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_vert,
                                color: Colors.grey[500],
                              ),
                              onSelected: (String result) {
                                _updateRequestStatus(request.id, result);
                              },
                              itemBuilder: (BuildContext context) =>
                              <PopupMenuEntry<String>>[
                                const PopupMenuItem<String>(
                                  value: 'Fulfilled',
                                  child: Text('Mark as Fulfilled'),
                                ),
                                const PopupMenuItem<String>(
                                  value: 'Active',
                                  child: Text('Mark as Active'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PostPage(onPost: _addRequest),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class PostPage extends StatefulWidget {
  final Function(Request) onPost;

  const PostPage({super.key, required this.onPost});

  @override
  State<PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contactController = TextEditingController();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  String _requestType = 'Take';

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState!.validate() && currentUser != null) {
      final newRequest = Request(
        id: '',
        userId: currentUser!.uid,
        title: _titleController.text,
        description: _descriptionController.text,
        contactInfo: _contactController.text,
        requestType: _requestType,
      );
      widget.onPost(newRequest);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create New Post")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: "Title",
                  hintText: "e.g., 'Graphing Calculator'",
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: "Description",
                  hintText: "e.g., 'Size Medium, in good condition'",
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _contactController,
                decoration: const InputDecoration(
                  labelText: "Contact Info",
                  hintText: "e.g., 'Email' or 'Phone Number'",
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your contact information';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _requestType,
                decoration: const InputDecoration(labelText: "Looking to..."),
                dropdownColor: Theme.of(context).cardColor,
                items: ['Take', 'Borrow']
                    .map(
                      (label) =>
                      DropdownMenuItem(value: label, child: Text(label)),
                )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _requestType = value!;
                  });
                },
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _submitForm,
                child: const Text("Post Request"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  final User? user;

  const ProfilePage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_circle,
                size: 100, color: Colors.cyanAccent),
            const SizedBox(height: 20),
            Text(
              // 🔥 TODO: Load profile details from database here (STUCK, I THOUGHT THIS WOULD DO IT)
              "User ID:",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                user?.uid ?? "Not signed in",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 16),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Is Anonymous: ${user?.isAnonymous}",
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}