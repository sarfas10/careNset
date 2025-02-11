import 'package:care_nest/campaignDetailsPage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PaymentStatus extends StatefulWidget {
  final String campaignId;
  final dynamic amount; // Amount passed from the previous page

  const PaymentStatus({Key? key, required this.campaignId, required this.amount}) : super(key: key);

  @override
  State<PaymentStatus> createState() => _PaymentStatusState();
}

class _PaymentStatusState extends State<PaymentStatus> {
  bool? isSuccess; // Will hold the payment status
  String? organizerId; // To store the organizer ID
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _fetchOrganizerId(); // Fetch the organizerId before checking payment status
  }

  Future<void> _fetchOrganizerId() async {
    try {
      // Fetch campaign data from Firestore using campaignId
      DocumentSnapshot campaignDoc = await FirebaseFirestore.instance
          .collection('campaigns')
          .doc(widget.campaignId)
          .get();

      if (campaignDoc.exists) {
        // Extract user_id (organizerId) from the campaign data
        setState(() {
          organizerId = campaignDoc['user_id'];
        });

        print('Organizer ID fetched: $organizerId');

        // Once organizerId is fetched, check payment status
        _checkPaymentStatus();
      } else {
        print('Campaign document does not exist.');
        setState(() {
          isSuccess = false;
        });
      }
    } catch (e) {
      print('Error fetching organizer ID: $e');
      setState(() {
        isSuccess = false;
      });
    }
  }

  Future<void> _checkPaymentStatus() async {
    try {
      // Get the logged-in user
      final User? user = _auth.currentUser;
      if (user == null) {
        print('No user is logged in.');
        return;
      }

      final String userId = user.uid;
      print('User ID: $userId');

      // Query the payments collection for the user's payment status
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('payments')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true) // Get the latest payment
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final DocumentSnapshot payment = snapshot.docs.first;

        print('Payment document fetched: ${payment.data()}');

        final status = payment['status'];
        print('Payment status: $status');

        setState(() {
          isSuccess = status == 'success';
          print('isSuccess set to: $isSuccess');
        });

        // If payment is successful, process the donation
        if (isSuccess!) {
          // Add a new entry to the donations collection
          final donationRef = await FirebaseFirestore.instance.collection('donations').add({
            'organiserId': organizerId, // Use the fetched organizerId
            'donorId': userId,
            'timestamp': FieldValue.serverTimestamp(),
            'amount': widget.amount,
            'status': 'success',
          });

          print('Donation record created successfully.');

          // Update the wallet balance
          final DocumentReference walletRef =
              FirebaseFirestore.instance.collection('wallet').doc(organizerId);

          final DocumentSnapshot walletDoc = await walletRef.get();

          if (walletDoc.exists) {
            // If wallet exists, update the balance
            final double currentBalance = walletDoc['balance'] ?? 0.0;
            final double newBalance = currentBalance + widget.amount;

            await walletRef.update({'balance': newBalance});

            print('Wallet updated with new balance: $newBalance');
          } else {
            // If wallet does not exist, create a new wallet document
            await walletRef.set({
              'userId': organizerId,
              'balance': widget.amount,
            });

            print('New wallet created with initial balance: ${widget.amount}');
          }

          // Add to wallet history
          final DocumentReference walletHistoryRef =
              FirebaseFirestore.instance.collection('walletHistory').doc(organizerId);

          final walletHistoryDoc = await walletHistoryRef.get();

          if (!walletHistoryDoc.exists) {
            // Create the walletHistory document if it doesn't exist
            final timestamp = FieldValue.serverTimestamp();
            await walletHistoryRef.set({
               'flow': 'in',
               'flowId': donationRef.id,
               'amount': widget.amount,
               'timestamp': FieldValue.serverTimestamp(), // Initialize with an empty list
            });
          }else{
            final timestamp = FieldValue.serverTimestamp();
             await walletRef.update({
              'flow': 'in',
               'flowId': donationRef.id,
               'amount': widget.amount,
               'timestamp': FieldValue.serverTimestamp(),
              });
          }

          // Add a new entry to the wallet history
         // Add a new entry to the wallet history
              


          print('Wallet history updated with a new entry.');

          // Update the `raised` field in the `campaigns` collection
          final DocumentReference campaignRef =
              FirebaseFirestore.instance.collection('campaigns').doc(widget.campaignId);

          final DocumentSnapshot campaignDoc = await campaignRef.get();

          if (campaignDoc.exists) {
            final campaignData = campaignDoc.data() as Map<String, dynamic>;
            final double currentRaised = campaignData['raised'] ?? 0.0;
            final double newRaised = currentRaised + widget.amount;
            await campaignRef.update({'raised': newRaised});

            print('Campaign raised amount updated to: $newRaised');
          } else {
            print('Campaign document does not exist.');
          }
        }

        // Delete the payment document after processing the payment status
        await FirebaseFirestore.instance
            .collection('payments')
            .doc(payment.id)
            .delete();

        print('Payment document deleted successfully.');
      } else {
        print('No payment records found for user.');
        setState(() {
          isSuccess = false;
        });
      }
    } catch (e) {
      print('Error fetching or deleting payment status: $e');
      setState(() {
        isSuccess = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isSuccess == null) {
      // Show a loading indicator while fetching data
      print('Fetching payment status...'); // Debug print
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Display success or failure image
              SizedBox(
                width: 400,
                height: 400,
                child: Image.asset(
                  isSuccess! ? 'assets/completed.png' : 'assets/failed.png',
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(height: 20),
              // Display success or failure message
              Text(
                isSuccess!
                    ? 'Thank you for your generosity! Your contribution has been successfully processed.'
                    : 'Oops! Something went wrong. Please try again.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[800]),
              ),
              SizedBox(height: 30),
              // Retry or make another donation button
              ElevatedButton(
                onPressed: () {
                  if (isSuccess!) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CampaignDetailPage(
                          campaignId: widget.campaignId,
                        ),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CampaignDetailPage(
                          campaignId: widget.campaignId,
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: Size(double.infinity, 50),
                ),
                child: Text(isSuccess! ? 'Make Another Donation' : 'Try Again'),
              ),
              SizedBox(height: 10),
              // Go to home screen button
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Navigate to the home screen
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: Size(double.infinity, 50),
                ),
                child: Text('Go to Home Screen'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
