import 'dart:html' as html;
import 'dart:io';
import 'package:care_nest/kycVerificationPage.dart';
import 'package:care_nest/payoutRequestsPage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AdminDashboard extends StatefulWidget {
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String _userName = 'Loading...';
  String _profileImageUrl = '';
  bool _isLoading = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _fetchUserDetails();
  }

  Future<void> _fetchUserDetails() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .get();

        setState(() {
          _userName = userDoc.get('name') ?? 'Admin';
          _profileImageUrl = userDoc.data() != null && 
              (userDoc.data() as Map<String, dynamic>).containsKey('profileImageUrl')
              ? userDoc.get('profileImageUrl')
              : '';
        });
      }
    } catch (e) {
      print('Error fetching user details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch user details'))
      );
    }
  }
  // final cloudinaryUrl = 'https://api.cloudinary.com/v1_1/dxeunc4vd/image/upload';
  // final uploadPreset = 'careNest';
  Future<void> _uploadProfilePicture() async {
  try {
    // Allow the user to pick an image
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null) return; // User canceled the picker

    setState(() {
      _isLoading = true;
    });

    // Check if the file is available as bytes (for web compatibility)
    final bytes = result.files.single.bytes; // Use bytes for web
    final filename = result.files.single.name;

    if (bytes == null) {
      throw Exception('File data is not available');
    }

    // Create a multipart request
    final cloudinaryUrl = 'https://api.cloudinary.com/v1_1/dxeunc4vd/image/upload';
    final uploadPreset = 'careNest';
    final request = http.MultipartRequest('POST', Uri.parse(cloudinaryUrl))
      ..fields['upload_preset'] = uploadPreset
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
      ));

    final response = await request.send();

    if (response.statusCode == 200) {
      final responseData = await http.Response.fromStream(response);
      final data = json.decode(responseData.body);

      // Get the URL of the uploaded image
      final String imageUrl = data['secure_url'];

      // Save the URL to Firestore
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        await _firestore.collection('users').doc(currentUser.uid).update({
          'profileImageUrl': imageUrl,
        });
      }

      setState(() {
        _profileImageUrl = imageUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated successfully')),
      );
    } else {
      throw Exception('Failed to upload image');
    }
  } catch (e) {
    print('Error uploading profile picture: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to upload profile picture')),
    );
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}





  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Left Navigation Panel
          Container(
            width: 250,
            color: Colors.grey[200],
            child: Column(
              children: [
                const SizedBox(height: 40),
                GestureDetector(
                  onTap: _isLoading ? null : _uploadProfilePicture,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundImage: _profileImageUrl.isNotEmpty
                            ? NetworkImage(_profileImageUrl)
                            : AssetImage('assets/profile_placeholder.png') as ImageProvider,
                      ),
                      if (_isLoading)
                        Positioned.fill(
                          child: Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        ),
                      if (!_isLoading)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _userName,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const Text(
                  'Role: Admin',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 30),
                ListTile(
                  leading: const Icon(Icons.attach_money),
                  title: const Text('Manage Payouts'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => PayoutRequestsPage()),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.verified_user),
                  title: const Text('Approve KYC'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => VerificationRequestsPage()),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Logout'),
                  onTap: () {
                    _auth.signOut();
                    Navigator.of(context).pushReplacementNamed('/login');
                  },
                ),
              ],
            ),
          ),

          // Main Content 
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dashboard',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      DateTime.now().toString().split(' ')[0], 
                      style: const TextStyle(color: Colors.grey)
                    ),
                    const SizedBox(height: 30),
                    // Blue Cards Section
                    Column(
                      children: [
                        DashboardBlueCard(
                          title: 'Total Users',
                          stream: FirebaseFirestore.instance.collection('users').snapshots(),
                        ),
                        const SizedBox(height: 10),
                        DashboardBlueCard(
                          title: 'Total Campaigns',
                          stream: FirebaseFirestore.instance.collection('campaigns').snapshots(),
                        ),
                        const SizedBox(height: 10),
                        DashboardBlueCard(
                          title: 'Total Donated',
                          stream: FirebaseFirestore.instance.collection('donations').snapshots(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardBlueCard extends StatelessWidget {
  final String title;
  final Stream<QuerySnapshot> stream;

  const DashboardBlueCard({required this.title, required this.stream});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      decoration: BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: stream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator(color: Colors.white);
                }
                final total = snapshot.data!.docs.length;
                return Text(
                  '$total',
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}