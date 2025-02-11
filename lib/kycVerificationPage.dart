import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VerificationRequestsPage extends StatefulWidget {
  @override
  _VerificationRequestsPageState createState() => _VerificationRequestsPageState();
}

class _VerificationRequestsPageState extends State<VerificationRequestsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> _fetchVerificationRequests() async {
    QuerySnapshot snapshot =
        await _firestore.collection('verification').get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id; // Add document ID for detailed navigation
      return data;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Verification Requests")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchVerificationRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error fetching data"));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text("No Verification Requests"));
          }

          List<Map<String, dynamic>> verificationRequests = snapshot.data!;
          return ListView.builder(
            itemCount: verificationRequests.length,
            itemBuilder: (context, index) {
              final request = verificationRequests[index];
              return ListTile(
                leading: Icon(Icons.verified_user),
                title: Text("Name: ${request['name']}"),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Status: ${request['status'] ?? 'pending'}"),
                  ],
                ),
                trailing: Icon(Icons.arrow_forward),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VerificationDetailsPage(
                        requestId: request['id'],
                        requestData: request,
                      ),
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

class VerificationDetailsPage extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> requestData;

  VerificationDetailsPage({required this.requestId, required this.requestData});

  @override
  _VerificationDetailsPageState createState() => _VerificationDetailsPageState();
}

class _VerificationDetailsPageState extends State<VerificationDetailsPage> {
  bool _isLoading = false;

  Future<void> _approveVerification(String enteredPassword) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("No admin is logged in.");
      }

      final AuthCredential credential =
          EmailAuthProvider.credential(email: user.email!, password: enteredPassword);
      await user.reauthenticateWithCredential(credential);

      final String userId = widget.requestData['userId'];

      // Update organiser field in the user's collection
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'organiser': "Yes",
      });

      final notificationsRef = FirebaseFirestore.instance.collection('notifications').doc(userId);
      await notificationsRef.set({
        'userId': userId,
        'notification': "Your KYC Verification has been completed successfully. You can now host donation campaigns.",
        'seen':false,
      });
      await FirebaseFirestore.instance
              .collection('verification')
              .doc(widget.requestId)
              .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Verification approved successfully.")),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _rejectVerification(String enteredPassword, String message) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("No admin is logged in.");
      }

      final AuthCredential credential =
          EmailAuthProvider.credential(email: user.email!, password: enteredPassword);
      await user.reauthenticateWithCredential(credential);

      final String userId = widget.requestData['userId'];

      final notificationsRef = FirebaseFirestore.instance.collection('notifications').doc(userId);
      await notificationsRef.set({
        'userId': userId,
        'notification': "Your KYC Verification request has been rejected. Reason: $message",
        'seen':false,
      });
      await FirebaseFirestore.instance
              .collection('verification')
              .doc(widget.requestId)
              .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Verification rejected successfully.")),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showPasswordPrompt({required bool isReject}) {
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isReject ? "Reject Verification" : "Approve Verification"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isReject) ...[
                Text("Enter a reason for rejection."),
                SizedBox(height: 10),
                TextField(
                  controller: messageController,
                  decoration: InputDecoration(
                    labelText: "Message",
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 20),
              ],
              Text("Enter your password to confirm."),
              SizedBox(height: 10),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final String enteredPassword = passwordController.text;
                final String message = messageController.text;
                Navigator.pop(context);
                if (isReject) {
                  await _rejectVerification(enteredPassword, message);
                } else {
                  await _approveVerification(enteredPassword);
                }
              },
              child: Text("Confirm"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Verification Details")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Name: ${widget.requestData['name']}", style: TextStyle(fontSize: 18)),
              SizedBox(height: 10),
              Text("Address: ${widget.requestData['address']}", style: TextStyle(fontSize: 16)),
              SizedBox(height: 10),
              Text("Nationality: ${widget.requestData['nationality']}", style: TextStyle(fontSize: 16)),
              SizedBox(height: 10),
              Text("Document Type: ${widget.requestData['documentType']}", style: TextStyle(fontSize: 16)),
              SizedBox(height: 10),
              Text("Status: ${widget.requestData['status']}", style: TextStyle(fontSize: 16)),
              SizedBox(height: 20),
              if (widget.requestData['idProofUrl'] != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Document Image:", style: TextStyle(fontSize: 16)),
                    SizedBox(height: 10),
                    Image.network(widget.requestData['idProofUrl']),
                  ],
                ),
              SizedBox(height: 20),
              if (_isLoading)
                Center(child: CircularProgressIndicator()),
              if (!_isLoading) ...[
                ElevatedButton(
                  onPressed: () {
                    _showPasswordPrompt(isReject: false);
                  },
                  child: Text("Approve"),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    _showPasswordPrompt(isReject: true);
                  },
                  child: Text("Reject"),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
