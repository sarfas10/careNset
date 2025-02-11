import 'package:care_nest/payoutRequestsPage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PayoutDetailsPage extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> requestData;

  PayoutDetailsPage({required this.requestId, required this.requestData});

  @override
  _PayoutDetailsPageState createState() => _PayoutDetailsPageState();
}

class _PayoutDetailsPageState extends State<PayoutDetailsPage> {
  bool _isLoading = false;

  String formatTimestamp(dynamic timestamp) {
    try {
      DateTime dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is DateTime) {
        dateTime = timestamp;
      } else {
        return "Invalid date";
      }
      return DateFormat('dd MMMM yyyy, hh:mm a').format(dateTime);
    } catch (e) {
      return "Invalid date";
    }
  }

  Future<void> completePayout(String enteredPassword) async {
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
      final int amount = widget.requestData['amount'];

      final walletRef = FirebaseFirestore.instance.collection('wallet').doc(userId);
      final walletSnapshot = await walletRef.get();

      if (walletSnapshot.exists) {
        final walletData = walletSnapshot.data()!;
        final int currentBalance = walletData['balance'] ?? 0;

        if (currentBalance >= amount) {
          await walletRef.update({'balance': currentBalance - amount});

          final notificationsRef = FirebaseFirestore.instance.collection('notifications').doc(userId);
          await notificationsRef.set({
            'userId': userId,
            'notification': "Your payout request of $amount has been completed.",
            'seen':false,
          });

          final DocumentReference payoutRef = FirebaseFirestore.instance.collection('payout').doc();
          final String payoutId = payoutRef.id;
          final DateTime timestamp = DateTime.now();

          await payoutRef.set({
            'userId': userId,
            'amount': amount,
            'timestamp': timestamp,
          });

          final walletHistoryRef = FirebaseFirestore.instance.collection('walletHistory').doc();
          await walletHistoryRef.set({
            'userId': userId,
            'amount': amount,
            'flow': 'out',
            'flowId': payoutId,
            'timestamp': timestamp,
          });

          await FirebaseFirestore.instance
              .collection('payoutRequests')
              .doc(widget.requestId)
              .delete();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Payout completed successfully.")),
            );

            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PayoutRequestsPage()),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Insufficient wallet balance.")),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("User's wallet not found.")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> cancelPayout(String enteredPassword, String message) async {
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
        'notification': "Your payout request has been cancelled. Reason: $message",
        'seen':false,
      });

      await FirebaseFirestore.instance
          .collection('payoutRequests')
          .doc(widget.requestId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Payout request cancelled successfully.")),
        );

        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PayoutRequestsPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void showPasswordPrompt({required bool isCancel}) {
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isCancel ? "Cancel Payout" : "Confirm Payout"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCancel) ...[
                Text("Enter a reason for cancellation."),
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
                if (mounted) Navigator.pop(context);
              },
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final String enteredPassword = passwordController.text;
                final String message = messageController.text;
                if (mounted) Navigator.pop(context);
                if (isCancel) {
                  await cancelPayout(enteredPassword, message);
                } else {
                  await completePayout(enteredPassword);
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
    final String payoutMethod = widget.requestData['payoutMethod'] ?? 'N/A';
    final dynamic timestamp = widget.requestData['requestedAt'];

    return Scaffold(
      appBar: AppBar(
        title: Text("Payout Details"),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Payout Request ID: ${widget.requestId}",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    SizedBox(height: 20),
                    Text("Amount: ${widget.requestData['amount']}"),
                    SizedBox(height: 10),
                    Text("Payout Method: $payoutMethod"),
                    SizedBox(height: 10),
                    Text("Requested At: ${timestamp != null ? formatTimestamp(timestamp) : 'N/A'}"),
                    SizedBox(height: 20),
                    if (payoutMethod.toLowerCase() == 'upi') ...[
                      Text("UPI ID: ${widget.requestData['upiId'] ?? 'N/A'}"),
                      SizedBox(height: 10),
                      widget.requestData['qrImageUrl'] != null
                          ? Image.network(widget.requestData['qrImageUrl'])
                          : Text("No QR Code available"),
                    ] else if (payoutMethod.toLowerCase() == 'bank') ...[
                      Text("Bank Name: ${widget.requestData['bankName'] ?? 'N/A'}"),
                      SizedBox(height: 10),
                      Text("IFSC Code: ${widget.requestData['ifscCode'] ?? 'N/A'}"),
                      SizedBox(height: 10),
                      Text("Bank Account Number: ${widget.requestData['bankAccountNumber'] ?? 'N/A'}"),
                      SizedBox(height: 10),
                      Text("Bank Branch: ${widget.requestData['bankBranch'] ?? 'N/A'}"),
                    ] else ...[
                      Text("No details available for the selected payout method."),
                    ],
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        showPasswordPrompt(isCancel: false);
                      },
                      child: Text("Payout Completed"),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      
                      onPressed: () {
                        showPasswordPrompt(isCancel: true);
                      },
                      child: Text("Cancel Request"),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
