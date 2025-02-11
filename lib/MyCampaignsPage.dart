import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MyCampaignsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: Text('My Campaigns')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('campaigns')
            .where('user_id', isEqualTo: currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No campaigns found.'));
          }

          var campaigns = snapshot.data!.docs;

          return ListView.builder(
            itemCount: campaigns.length,
            itemBuilder: (context, index) {
              var campaign = campaigns[index];
              return Card(
                margin: EdgeInsets.all(10),
                elevation: 3,
                child: ListTile(
                  leading: campaign['image_url'] != null
                      ? Image.network(
                          campaign['image_url'],
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        )
                      : Icon(Icons.campaign, size: 50),
                  title: Text(campaign['title'], style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(campaign['description'], maxLines: 2, overflow: TextOverflow.ellipsis),
                      Text('Raised: \$${campaign['raised']} / \$${campaign['amount']}',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
