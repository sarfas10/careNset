import 'package:care_nest/KycFormPage.dart';
import 'package:care_nest/MyCampaignsPage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String userId = "";
  String profileUrl = "";
  String name = "";
  String email = "";
  String phoneNumber = "";
  String location = "";
  int totalCampaigns = 0;
  double totalDonated = 0;
  double totalGenerated = 0;
  String organiserStatus = "no";
  String stripeAccountId = "";
  String _profileImageUrl = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchUserId();
  }

  Future<void> fetchUserId() async {
    final User? user = _auth.currentUser;
    if (user != null) {
      setState(() {
        userId = user.uid;
      });
      await fetchUserData();
      await fetchCampaignStats();
    }
  }

  Future<void> fetchUserData() async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final data = userDoc.data();
    if (data != null) {
      setState(() {
        _profileImageUrl = userDoc.data() != null &&
                (userDoc.data() as Map<String, dynamic>).containsKey('profileImageUrl')
            ? userDoc.get('profileImageUrl')
            : '';
        name = data['name'] ?? "User Name";
        email = data['email'] ?? "Not provided";
        phoneNumber = data['contact'] ?? "Not provided";
        location = data['location'] ?? "Not provided";
        organiserStatus = data['organiser'] ?? "no";
        stripeAccountId = data['stripeAccountId'] ?? "";
      });
    }
  }

  Future<void> fetchCampaignStats() async {
    final campaigns = await _firestore
        .collection('campaigns')
        .where('user_id', isEqualTo: userId)
        .get();

    double totalDonated = 0.0;
    double totalGenerated = 0.0;

    try {
      QuerySnapshot donorSnapshot = await _firestore
          .collection('donations')
          .where('donorId', isEqualTo: userId)
          .where('status', isEqualTo: 'success')
          .get();

      for (var doc in donorSnapshot.docs) {
        totalDonated += doc['amount'];
      }

      QuerySnapshot organiserSnapshot = await _firestore
          .collection('donations')
          .where('organiserId', isEqualTo: userId)
          .where('status', isEqualTo: 'success')
          .get();

      for (var doc in organiserSnapshot.docs) {
        totalGenerated += doc['amount'];
      }

      setState(() {
        this.totalDonated = totalDonated;
        this.totalGenerated = totalGenerated;
      });
    } catch (e) {
      print('Error fetching donation stats: $e');
    }

    setState(() {
      totalCampaigns = campaigns.docs.length;
    });
  }

  Future<void> _uploadProfilePicture() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result == null) return;

      setState(() {
        _isLoading = true;
      });

      final bytes = result.files.single.bytes;
      final filename = result.files.single.name;

      if (bytes == null) {
        throw Exception('File data is not available');
      }

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

        final String imageUrl = data['secure_url'];

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
      backgroundColor: Color(0xFF1E1E2C),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: _profileImageUrl.isNotEmpty
                        ? NetworkImage(_profileImageUrl)
                        : AssetImage('assets/profile_placeholder.png') as ImageProvider,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _isLoading ? null : _uploadProfilePicture,
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Color(0xFF6C63FF),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Center(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard(
                  'Campaigns',
                  totalCampaigns.toString(),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => MyCampaignsPage()),
                    );
                  },
                ),
                _buildStatCard('Donated', '\$${totalDonated.toStringAsFixed(2)}'),
                _buildStatCard('Generated', '\$${totalGenerated.toStringAsFixed(2)}'),
              ],
            ),
            SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.person, color: Colors.white),
                    SizedBox(width: 16),
                    Text(
                      "Verifications",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: organiserStatus == "yes"
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => KYCFormPage()),
                          );
                        },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: organiserStatus == "yes"
                          ? Colors.green
                          : Color(0xFF6C63FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      organiserStatus == "yes" ? "Verified" : "Verify",
                      style: TextStyle(
                        color: organiserStatus == "yes"
                            ? Colors.white
                            : Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            _buildInfoRow(Icons.email, "Email", email),
            SizedBox(height: 16),
            _buildInfoRow(Icons.phone, "Phone", phoneNumber),
            SizedBox(height: 16),
            _buildInfoRow(Icons.location_on, "Location", location),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Color(0xFF2A2D3E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.white),
          SizedBox(width: 20),
          Text(
            "$label:",
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          Spacer(),
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                value,
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
