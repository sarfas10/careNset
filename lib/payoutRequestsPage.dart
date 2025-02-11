import 'package:care_nest/PayoutDetailsPage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PayoutRequestsPage extends StatefulWidget {
  @override
  _PayoutRequestsPageState createState() => _PayoutRequestsPageState();
}

class _PayoutRequestsPageState extends State<PayoutRequestsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> _fetchPayoutRequests() async {
    QuerySnapshot snapshot =
        await _firestore.collection('payoutRequests').get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id; // Add document ID for detailed navigation
      return data;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Payout Requests")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchPayoutRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error fetching data"));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text("No Payout Requests"));
          }

          List<Map<String, dynamic>> payoutRequests = snapshot.data!;
          return ListView.builder(
            itemCount: payoutRequests.length,
            itemBuilder: (context, index) {
              final request = payoutRequests[index];
              return ListTile(
                leading: Icon(Icons.account_balance_wallet),
                title: Text("Amount: ${request['amount']}"),
                subtitle: Text("Method: ${request['payoutMethod'] ?? 'N/A'}"),
                trailing: Icon(Icons.arrow_forward),
                onTap: () {
                  // Navigate to the detailed view
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PayoutDetailsPage(
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
