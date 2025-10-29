import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../app_navigator.dart';

class Requester extends StatelessWidget {
  const Requester({super.key});

  @override
  Widget build(BuildContext context) {
    return const RequesterHomePage();
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

class RequesterHomePage extends StatefulWidget {
  const RequesterHomePage({super.key});

  @override
  State<RequesterHomePage> createState() => _RequesterHomePageState();
}

class _RequesterHomePageState extends State<RequesterHomePage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final CollectionReference requestsCollection = FirebaseFirestore.instance
      .collection('requests');
  final CollectionReference listingsCollection = FirebaseFirestore.instance
      .collection('listings');
  final CollectionReference usersCollection = FirebaseFirestore.instance
      .collection('users');

  bool _filterBySchool = true;

  @override
  void dispose() {
    super.dispose();
  }

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

  void _openHelpChat() {
    appNavigatorKey.currentState?.push(
      MaterialPageRoute(builder: (context) => const HelpChatPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileFuture = usersCollection.doc(currentUser?.uid).get();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Your Postings"),
          bottom: const TabBar(tabs: [Tab(text: 'Your Posts'), Tab(text: 'Listings')]),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: 'Help',
              onPressed: _openHelpChat,
            ),
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
        body: TabBarView(children: [
          StreamBuilder<QuerySnapshot>(
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

          FutureBuilder<DocumentSnapshot>(
            future: usersCollection.doc(currentUser?.uid).get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                return Center(child: Text('No profile info found.', style: TextStyle(color: Colors.grey[500])));
              }
              final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
              final schoolName = userData?['schoolName'] ?? '';

              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Theme.of(context).cardColor,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _filterBySchool ? Icons.school : Icons.public,
                              size: 20,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _filterBySchool ? 'My School Only' : 'All Schools',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[300],
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: _filterBySchool,
                          onChanged: (value) {
                            setState(() {
                              _filterBySchool = value;
                            });
                          },
                          activeColor: Colors.cyanAccent[400],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _filterBySchool
                          ? listingsCollection
                          .where('schoolName', isEqualTo: schoolName)
                          .orderBy('timestamp', descending: true)
                          .snapshots()
                          : listingsCollection
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
                            child: Text(
                              _filterBySchool
                                  ? 'No listings available for your school'
                                  : 'No listings available',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          );
                        }
                        final docs = snapshot.data!.docs;
                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final imageUrl = data['imageUrl'] as String? ?? '';
                            final listingSchool = data['schoolName'] as String? ?? '';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(12),
                                leading: imageUrl.isNotEmpty
                                    ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: 72,
                                    height: 72,
                                    child: CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (c, s) => Container(
                                        color: Colors.grey[800],
                                        child: const Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                        ),
                                      ),
                                      errorWidget: (c, s, e) => Container(
                                        color: Colors.grey[800],
                                        child: const Icon(Icons.broken_image, color: Colors.grey),
                                      ),
                                      fadeInDuration: const Duration(milliseconds: 200),
                                      fadeOutDuration: const Duration(milliseconds: 200),
                                    ),
                                  ),
                                )
                                    : Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[800],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.photo, color: Colors.grey),
                                ),
                                title: Text(
                                  data['title'] ?? '',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      data['description'] ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (listingSchool.isNotEmpty && !_filterBySchool && listingSchool != schoolName) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.school, size: 14, color: Colors.grey[500]),
                                          const SizedBox(width: 4),
                                          Text(
                                            listingSchool,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: Text(
                                  data['contactInfo'] ?? '',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ]),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            appNavigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (context) => PostPage(onPost: _addRequest),
              ),
            );
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class HelpChatPage extends StatefulWidget {
  const HelpChatPage({super.key});

  @override
  State<HelpChatPage> createState() => _HelpChatPageState();
}

class _HelpChatPageState extends State<HelpChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  static const String GEMINI_API_KEY = 'AIzaSyCbUA8yA0taJeBeoU_8A9G_gJUrWuh7vc4';

  final String systemPrompt = '''
You are a helpful assistant for EduShare, a student-to-student resource sharing app. Your role is to help users understand how to use the app effectively.

EduShare has two main roles:

1. REQUESTER MODE (where users currently are):
   - "Your Posts" tab: View your own requests for items you need
     * Create posts for items you're looking to "Take" (permanently) or "Borrow" (temporarily)
     * Mark requests as "Fulfilled" when you get the item, or "Active" to reopen them
     * Each post includes: title, description, contact info, and request type
   - "Listings" tab: Browse items that donators are offering
     * Toggle between "My School Only" and "All Schools" using the switch at the top
     * When viewing all schools, listings from other schools show a school badge
     * See item images, descriptions, and contact info to reach out to donors
   - Plus button (+): Create a new request for an item you need
   - Help button: Opens this chat assistant (where you are now)
   - Profile button: View your account details and school information

2. DONATOR MODE (accessible via the menu drawer):
   - View all active requests from students who need items
   - Create listings to offer items you want to give away or lend
   - Upload images of your items when creating listings
   - Your listings are visible to students at your school (or all schools if they toggle the filter)
   - Only you can update the status of your own requests

KEY FEATURES:
- School filtering: By default, requesters only see listings from their school, but can toggle to view all
- Image uploads: Donators can add photos to their listings
- Contact info: Each post/listing includes contact details for direct communication
- Status tracking: Mark items as "Active" or "Fulfilled"
- Two-way marketplace: Both ask for items (requests) and offer items (listings)

NAVIGATION:
- Use the hamburger menu (☰) to switch between Requester and Donator modes
- Sign out button in the menu or top-right
- Profile shows your display name, school, and account details

Answer user questions clearly and concisely. If they ask about features not mentioned here, politely explain that the app focuses on simple peer-to-peer item sharing between students. Keep responses helpful and friendly.
''';

  @override
  void initState() {
    super.initState();
    _messages.add(ChatMessage(
      text: "Hi! I'm here to help you use EduShare. Ask me anything about how the app works!",
      isUser: false,
    ));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: message, isUser: true));
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final response = await _getGeminiResponse(message);
      setState(() {
        _messages.add(ChatMessage(text: response, isUser: false));
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: "Sorry, I'm having trouble connecting right now. Error: ${e.toString()}\n\nPlease make sure your API key is configured correctly.",
          isUser: false,
        ));
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Future<String> _getGeminiResponse(String userMessage) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=$GEMINI_API_KEY',
    );

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': systemPrompt},
              {'text': 'User question: $userMessage'},
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 500,
        }
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text'];
    } else {
      print('API Error: ${response.statusCode}');
      print('Response body: ${response.body}');
      throw Exception('Failed to get response: ${response.statusCode} - ${response.body}');
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.cyanAccent[400]!,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Thinking...',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Ask me anything about EduShare...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).scaffoldBackgroundColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: _isLoading ? null : _sendMessage,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.cyanAccent[400]!,
                        Colors.greenAccent[400]!,
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _isLoading
                        ? null
                        : () => _sendMessage(_messageController.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: message.isUser
              ? Colors.cyanAccent[400]
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.isUser ? Colors.black87 : Colors.white,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
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