import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
// ignore: unused_import
import 'dart:convert';

class AdminVerificationPage extends StatelessWidget {
  // ignore: unused_field
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<QuerySnapshot> _fetchPendingDocuments() {
    return FirebaseFirestore.instance
        .collection('verification')
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  // Function to delete image from Cloudinary
  Future<void> _deleteImageFromCloudinary(String imageUrl) async {
    try {
      // Extract the public ID from the image URL
      Uri uri = Uri.parse(imageUrl);
      String publicId = uri.pathSegments.last.split('.').first;

      // Your Cloudinary Cloud name and API key/secret
      String cloudName = 'dxeunc4vd';
      String apiKey = 'your-api-key';
      String apiSecret = 'your-api-secret';

      // Create the API URL for deleting the image
      final apiUrl =
          'https://api.cloudinary.com/v1_1/$cloudName/image/destroy';
      final response = await http.post(
        Uri.parse(apiUrl),
        body: {
          'public_id': publicId,
          'api_key': apiKey,
          'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
          'signature': _generateSignature(apiSecret, publicId),
        },
      );

      if (response.statusCode == 200) {
        print('Image deleted from Cloudinary');
      } else {
        print('Failed to delete image from Cloudinary');
      }
    } catch (e) {
      print('Error deleting image from Cloudinary: $e');
    }
  }

  // Function to generate signature for Cloudinary API
  String _generateSignature(String apiSecret, String publicId) {
    String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    String signatureString =
        'public_id=$publicId&timestamp=$timestamp$apiSecret';
    return Uri.encodeComponent(signatureString); // Make sure to encode the signature
  }

  // Function to approve the document
  Future<void> _approveDocument(String documentId, String imageUrl) async {
    try {
      await FirebaseFirestore.instance.collection('verification').doc(documentId).update({
        'status': 'approved',
      });

      // Delete the image from Cloudinary
      await _deleteImageFromCloudinary(imageUrl);

      // Optionally, you can delete the document from Firestore as well
      await FirebaseFirestore.instance.collection('verification').doc(documentId).delete();
      print('Document approved and deleted from Cloudinary');
    } catch (e) {
      print('Error approving document: $e');
    }
  }

  // Function to reject the document
  Future<void> _rejectDocument(String documentId) async {
    try {
      await FirebaseFirestore.instance.collection('verification').doc(documentId).update({
        'status': 'rejected',
      });
      print('Document rejected');
    } catch (e) {
      print('Error rejecting document: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Admin Document Verification')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _fetchPendingDocuments(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final documents = snapshot.data!.docs;

          return ListView.builder(
            itemCount: documents.length,
            itemBuilder: (context, index) {
              final document = documents[index];
              final documentUrl = document['documentUrl'];
              final userId = document['userId'];
              final documentId = document.id;

              return ListTile(
                title: Text('User: $userId'),
                subtitle: Text('Document: Pending'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.check, color: Colors.green),
                      onPressed: () async {
                        await _approveDocument(documentId, documentUrl);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Document approved.')));
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.red),
                      onPressed: () async {
                        await _rejectDocument(documentId);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Document rejected.')));
                      },
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DocumentViewPage(documentUrl: documentUrl),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class DocumentViewPage extends StatelessWidget {
  final String documentUrl;

  DocumentViewPage({required this.documentUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('View Document')),
      body: Center(
        child: Image.network(documentUrl),
      ),
    );
  }
}
