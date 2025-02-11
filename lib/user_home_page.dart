import 'package:care_nest/KycFormPage.dart';
import 'package:care_nest/campaignDetailsPage.dart';
import 'package:care_nest/profile.dart';
import 'package:care_nest/wallet.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_campaign_page.dart';

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  _UserHomePageState createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _showNotifications = false;

  String? userName;
  Map<String, String> categoryMap = {}; // To map category number to name
  List<Map<String, dynamic>> searchResults = [];
  String _searchQuery = "";
  bool _isListening = false;
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchUserName();
    fetchCategories();
  }

  Future<List<QueryDocumentSnapshot>> fetchCampaigns() async {
    QuerySnapshot snapshot = await _firestore.collection('campaigns').get();
    return snapshot.docs;
  }

  Future<void> _onSearch(String query) async {
  if (query.isEmpty) {
    setState(() {
      searchResults = [];
    });
    return;
  }

  try {
    // Convert query to lowercase
    String lowerCaseQuery = query.toLowerCase();

    // Fetch campaigns and categories
    QuerySnapshot campaignsSnapshot = await _firestore.collection('campaigns').get();
    QuerySnapshot categoriesSnapshot = await _firestore.collection('categories').get();

    // Map categories by ID
    Map<String, String> categoriesMap = {
      for (var doc in categoriesSnapshot.docs)
        doc.id: doc['name'] as String,
    };

    // Filter campaigns
    List<QueryDocumentSnapshot> filteredCampaigns = campaignsSnapshot.docs.where((doc) {
      var data = doc.data() as Map<String, dynamic>;
      String title = data['title']?.toLowerCase() ?? '';
      return title.contains(lowerCaseQuery);
    }).toList();

    // Update search results with `campaignId` included
    setState(() {
      searchResults = filteredCampaigns.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        data['campaignId'] = doc.id; // Add document ID
        data['categoryName'] = categoriesMap[data['category_id']] ?? 'General';
        return data;
      }).toList();
    });
  } catch (e) {
    print("Error searching campaigns: $e");
  }
}



  Future<void> _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (status) => print('Speech status: $status'),
      onError: (error) => print('Speech error: $error'),
    );

    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          setState(() {
            _searchQuery = result.recognizedWords;
            _searchController.text = _searchQuery; // Update the controller
            _onSearch(_searchQuery);
          });
        },
      );
    }
  }

  Future<void> _stopListening() async {
    setState(() => _isListening = false);
    _speech.stop();
  }

  Future<void> fetchUserName() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        String uid = currentUser.uid;

        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(uid).get();

        setState(() {
          userName = userDoc['name']; // Assuming 'name' field exists
        });
      }
    } catch (e) {
      print("Error fetching user name: $e");
    }
  }

  Future<void> fetchCategories() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('categories').get();

      setState(() {
        categoryMap = {
          for (var doc in snapshot.docs)
            doc.id: doc['name'] as String // Assuming 'name' is a field in the document
        };
      });
    } catch (e) {
      print("Error fetching categories: $e");
    }
  }

  @override
 Widget build(BuildContext context) {
  return Scaffold(
    body: SingleChildScrollView(
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 16), // Leave space for the notification overlay
                _buildHeaderSection(),
                SizedBox(height: 24),
                _buildSearchBar(),
                SizedBox(height: 24),
                _buildCampaignBanner(context),
                SizedBox(height: 24),
                _buildCampaignsSection(),
              ],
            ),
          ),
          if (_showNotifications)
            Positioned(
              top: 90, // Position it at the top of the page
              right: 16, // Align it to the right of the screen
              child: _buildNotificationsContainer(),
            ),
        ],
      ),
    ),
    bottomNavigationBar: _buildBottomNavigationBar(),
  );
}


Widget _buildHeaderSection() {
  return Stack(
    clipBehavior: Clip.none, // Allows the notification container to overflow outside the header section
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                userName != null ? "Hello, $userName 👋" : "Hello 👋",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "What do you wanna donate today?",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.notifications),
                onPressed: () {
                  setState(() {
                    _showNotifications = !_showNotifications;
                  });
                },
              ),
              StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('notifications')
                    .where('userId', isEqualTo: _auth.currentUser?.uid)
                    .where('seen', isEqualTo: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    return Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  }
                  return SizedBox.shrink();
                },
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      if (_showNotifications)
        Positioned(
          top: 50, // Adjust this value to position the container below the bell icon
          right: 0, // Align with the bell icon
          child: _buildNotificationsContainer(),
        ),
    ],
  );
}

 Widget _buildNotificationsContainer() {
  return Material(
    elevation: 8,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      width: 300,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('notifications')
            .where('userId', isEqualTo: _auth.currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Text(
              "No notifications.",
              style: TextStyle(color: Colors.grey),
            );
          }

          return ListView.builder(
            shrinkWrap: true,
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final notification = snapshot.data!.docs[index];
              final title = 'Notification:';
              final description =
                  notification['notification'] ?? 'Notification.';

              return ListTile(
                title: Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(description),
                trailing: IconButton(
                  icon: Icon(Icons.check),
                  onPressed: () {
                    // Mark as seen
                    notification.reference.delete();
      
                  },
                ),
              );
            },
          );
        },
      ),
    ),
  );
}

 Widget _buildSearchBar() {
  return Column(
    children: [
      TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
            _onSearch(value);
          });
        },
        decoration: InputDecoration(
          hintText: "Search here",
          prefixIcon: Icon(Icons.search),
          suffixIcon: IconButton(
            icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
            onPressed: _isListening ? _stopListening : _startListening,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
        ),
      ),
      if (_searchQuery.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 8.0),
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(16),
          ),
          constraints: BoxConstraints(
            maxHeight: 200,
          ),
          child: searchResults.isNotEmpty
              ? ListView.builder(
                  itemCount: searchResults.length,
                  itemBuilder: (context, index) {
                    final campaign = searchResults[index];
                    final campaignId = campaign['campaignId']; // Extract campaignId
                    final title = campaign['title'] ?? 'Untitled Campaign';
                    final imageUrl = campaign['image_url'] ?? '';
                    final description =
                        campaign['description'] ?? 'No description available.';

                    return ListTile(
                      leading: imageUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                imageUrl,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Icon(Icons.image_not_supported, size: 50),
                      title: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CampaignDetailPage(
                              campaignId: campaignId,
                            ),
                          ),
                        );
                      },
                    );
                  },
                )
              : Center(
                  child: Text(
                    "No results found.",
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
        ),
    ],
  );
}


  Widget _buildCampaignBanner(BuildContext context) {
    return Container(
      height: 180,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/hands.jpg'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.teal.withOpacity(0.6),
            BlendMode.srcOver,
          ),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Do you really have a creative idea?",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddCampaignPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 24,
                    ),
                    backgroundColor: Colors.teal[700],
                  ),
                  child: Text(
                    "Start Campaign",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Fundraisers",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),
        FutureBuilder<List<QueryDocumentSnapshot>>(
          future: fetchCampaigns(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text("Error fetching campaigns"));
            }

            if (snapshot.hasData && snapshot.data!.isEmpty) {
              return Center(child: Text("No campaigns found."));
            }

            return ListView.builder(
              physics: NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                var campaign = snapshot.data![index].data() as Map<String, dynamic>;
                String campaignId = snapshot.data![index].id;

                String categoryId = campaign['category_id'] as String;
                String categoryName = categoryMap[categoryId] ?? 'General';

                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CampaignDetailPage(
                          campaignId: campaignId,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 8),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          blurRadius: 5,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                campaign['image_url'] ?? '',
                                width: 100,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          campaign['title'] ?? 'Untitled Campaign',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green[100],
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Text(
                                          categoryName,
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    campaign['description'] ?? 'No description available.',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Raised: \$${campaign['raised'] ?? 0}",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                            ),
                            Text(
                              "${((campaign['raised'] ?? 0) / (campaign['amount'] ?? 1) * 100).clamp(0.0, 100.0).toStringAsFixed(0)}%",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: ((campaign['raised'] ?? 0) /
                                    (campaign['amount'] ?? 1))
                                .clamp(0.0, 1.0),
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation(Colors.teal),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      items: [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.account_balance_wallet),
          label: 'Wallet',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
      onTap: (index) {
        if (index == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => WalletPage()),
          );
        } else if (index == 2) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ProfilePage()),
          );
        }
      },
    );
  }
}
