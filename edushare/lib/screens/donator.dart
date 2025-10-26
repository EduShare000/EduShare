import 'package:flutter/material.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:firebase_auth/firebase_auth.dart';
import '../app_navigator.dart';

/// A lightweight wrapper widget exported for use inside the app shell.
class Donator extends StatelessWidget {
  const Donator({super.key});

  @override
  Widget build(BuildContext context) {
    // The main MaterialApp is provided by `main.dart` (AppShell).
    return const DonatorHomePage();
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
      'timestamp': FieldValue.serverTimestamp(),
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

// Create Listing Page for Donators to post public listings
class CreateListingPage extends StatefulWidget {
  final Function(Listing) onPostListing;

  const CreateListingPage({super.key, required this.onPostListing});

  @override
  State<CreateListingPage> createState() => _CreateListingPageState();
}

class _CreateListingPageState extends State<CreateListingPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contactController = TextEditingController();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate() && currentUser != null) {
      // upload image first if selected
      _createListing();
    }
  }

  Future<void> _createListing() async {
    final uid = currentUser!.uid;
    String imageUrl = '';
      if (_pickedFile != null) {
      final fileName = path.basename(_pickedFile!.path);
      final ref = FirebaseStorage.instance.ref().child('listing_images/$uid/$fileName');
        await ref.putFile(File(_pickedFile!.path));
      imageUrl = await ref.getDownloadURL();
    }

    // read user's schoolName from users collection
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      String schoolName = '';
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>?;
        schoolName = data?['schoolName'] ?? '';
      }

    final listing = Listing(
      id: '',
      userId: uid,
      title: _titleController.text,
      description: _descriptionController.text,
      contactInfo: _contactController.text,
    );

    // return full map including schoolName and imageUrl
    final listingMap = listing.toJson();
    listingMap['schoolName'] = schoolName;
    listingMap['imageUrl'] = imageUrl;

    widget.onPostListing(Listing(
      id: '',
      userId: uid,
      title: listing.title,
      description: listing.description,
      contactInfo: listing.contactInfo,
    ));
    // directly write the map to the listings collection to include fields
    await FirebaseFirestore.instance.collection('listings').add(listingMap);

    appNavigatorKey.currentState?.pop();
  }

  XFile? _pickedFile;

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
    if (file != null) {
      setState(() {
        _pickedFile = file;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Listing')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => v == null || v.isEmpty ? 'Enter a title' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (v) => v == null || v.isEmpty ? 'Enter description' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactController,
                decoration: const InputDecoration(labelText: 'Contact Info'),
                validator: (v) => v == null || v.isEmpty ? 'Enter contact info' : null,
              ),
              const SizedBox(height: 12),
              // Image picker
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo),
                    label: const Text('Pick Image'),
                  ),
                  const SizedBox(width: 12),
                  if (_pickedFile != null)
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: Image.file(File(_pickedFile!.path), fit: BoxFit.cover),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _submit, child: const Text('Post Listing')),
            ],
          ),
        ),
      ),
    );
  }
}

class DonatorHomePage extends StatefulWidget {
  const DonatorHomePage({super.key});

  @override
  State<DonatorHomePage> createState() => _DonatorHomePageState();
}

class _DonatorHomePageState extends State<DonatorHomePage> {

  final User? currentUser = FirebaseAuth.instance.currentUser;
  final CollectionReference requestsCollection = FirebaseFirestore.instance
      .collection('requests');
  final CollectionReference listingsCollection = FirebaseFirestore.instance
    .collection('listings');
  final CollectionReference usersCollection = FirebaseFirestore.instance
      .collection('users');

  Future<void> _addRequest(Request newRequest) async {
    try {
      await requestsCollection.add(newRequest.toJson());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to post request: $e')));
      }
    }
  }

  Future<void> _addListing(Listing newListing) async {
    try {
      await listingsCollection.add(newListing.toJson());
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Listing posted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to post listing: $e')));
      }
    }
  }

  Future<void> _updateRequestStatus(String docId, String newStatus) async {
    try {
      await requestsCollection.doc(docId).update({'status': newStatus});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
      }
    }
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
    appNavigatorKey.currentState?.push(
      MaterialPageRoute(builder: (context) => ProfilePage(user: currentUser)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileFuture = usersCollection.doc(currentUser?.uid).get();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Your Postings"),
        actions: [
          FutureBuilder<DocumentSnapshot>(
            future: profileFuture,
            builder: (context, snapshot) {
              String profileName = currentUser?.uid ?? "Guest User";

              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                profileName =
                    data?['displayName'] ?? currentUser!.uid.substring(0, 8);
              } else if (snapshot.connectionState == ConnectionState.waiting) {
                profileName = "Loading...";
              } else if (currentUser != null) {
                profileName = currentUser!.uid.substring(0, 8);
              }

              return TextButton.icon(
                onPressed: _openProfile,
                icon: const Icon(Icons.account_circle, color: Colors.white),
                label: Text(
                  profileName,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: requestsCollection
            .where('userId', isEqualTo: currentUser?.uid)
            .orderBy('timestamp', descending: true)
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
                              style: TextStyle(color: Colors.grey[500]),
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
          appNavigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => CreateListingPage(onPostListing: _addListing),
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
      appNavigatorKey.currentState?.pop();
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
            const Icon(
              Icons.account_circle,
              size: 100,
              color: Colors.cyanAccent,
            ),
            const SizedBox(height: 20),
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user?.uid)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Text("Loading Profile Details...");
                }

                String displayName = "User ID:";
                String profileDetails = "No extra details found.";

                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>?;
                  displayName = data?['displayName'] ?? 'User ID:';
                  profileDetails =
                      data?['schoolName'] ?? 'No school registered.';
                }

                return Column(
                  children: [
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        profileDetails,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[500], fontSize: 16),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Text("User UID:", style: Theme.of(context).textTheme.bodyLarge),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                user?.uid ?? "Not signed in",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
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

class Listing {
  String id;
  String userId;
  String title;
  String description;
  String contactInfo;

  Listing({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.contactInfo,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'title': title,
        'description': description,
        'contactInfo': contactInfo,
        'timestamp': FieldValue.serverTimestamp(),
      };

  factory Listing.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Listing(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      contactInfo: data['contactInfo'] ?? '',
    );
  }
}