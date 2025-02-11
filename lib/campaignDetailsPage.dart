import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:care_nest/paymentStatus.dart';
import 'package:care_nest/services/stripe_service.dart';

class CampaignDetailPage extends StatefulWidget {
  final String campaignId;

  const CampaignDetailPage({required this.campaignId, Key? key}) : super(key: key);

  @override
  _CampaignDetailPageState createState() => _CampaignDetailPageState();
}

class _CampaignDetailPageState extends State<CampaignDetailPage> {
  Future<Map<String, dynamic>?> _fetchOrganizerData(String userId) async {
    try {
      DocumentSnapshot userDoc =
          await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return userDoc.data() as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint("Error fetching organizer data: $e");
    }
    return null;
  }

  void _showPaymentStatusPopup(String campaignId, double amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text("Payment Processed"),
          content: const Text("Your payment has been processed. Continue to view the status."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog

                // Navigate to the PaymentStatus page with the organizer's user ID
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PaymentStatus(campaignId: widget.campaignId, amount: amount),
                  ),
                );
              },
              child: const Text("Continue"),
            ),
          ],
        );
      },
    );
  }

  void _showDonationDialog(double remainingAmount, String campaignId, String organizerId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (context) {
        double donationAmount = 0.0;
        double tipAmount = 5.0;
        bool hideName = false;

        return Padding(
          padding: EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            top: 24.0,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  "How much do you want to donate?",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: [10, 50, 100, 200, 500, 1000].map((amount) {
                  return ChoiceChip(
                    label: Text("\$$amount"),
                    selected: donationAmount == amount,
                    onSelected: (selected) {
                      setState(() {
                        donationAmount = selected ? amount.toDouble() : 0.0;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Custom Amount",
                  prefixText: "\$",
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  donationAmount = double.tryParse(value) ?? 0.0;
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Tip us"),
                  Text("\$${tipAmount.toStringAsFixed(2)}"),
                ],
              ),
              Slider(
                value: tipAmount,
                min: 0,
                max: 20,
                divisions: 20,
                onChanged: (value) {
                  setState(() {
                    tipAmount = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Hide name"),
                  Switch(
                    value: hideName,
                    onChanged: (value) {
                      setState(() {
                        hideName = value;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  if (donationAmount <= 0 || donationAmount > remainingAmount) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          donationAmount <= 0
                              ? "Please enter a valid amount."
                              : "You can only donate up to \$${remainingAmount.toStringAsFixed(2)}.",
                        ),
                      ),
                    );
                    return;
                  }

                  await StripeService.instance.makePayment(donationAmount.toInt(), "usd");
                  Navigator.pop(context); // Close the donation dialog
                  _showPaymentStatusPopup(widget.campaignId, donationAmount);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3EB489),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text(
                  "Go to payment",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Campaign Details"),
        
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('campaigns')
            .doc(widget.campaignId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Error loading campaign details."));
          }

          var campaignData = snapshot.data!.data() as Map<String, dynamic>;
          String userId = campaignData['user_id'] ?? '';

          return FutureBuilder<Map<String, dynamic>?>(
            future: _fetchOrganizerData(userId),
            builder: (context, organizerSnapshot) {
              if (organizerSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              var organizerData = organizerSnapshot.data;
              String organizerName = organizerData?['name'] ?? 'Unknown Organizer';
              String organizerLocation = organizerData?['location'] ?? 'Unknown Location';

              double raised = campaignData['raised']?.toDouble() ?? 0.0;
              double goal = campaignData['amount']?.toDouble() ?? 1.0;
              double progress = (raised / goal).clamp(0.0, 1.0);
              double remainingAmount = (goal - raised).clamp(0.0, goal);

              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: campaignData['image_url'] != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12.0),
                                    child: Image.network(
                                      campaignData['image_url'],
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    child: const Center(child: Text("No Image Available")),
                                  ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            campaignData['title'] ?? 'Untitled Campaign',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const CircleAvatar(
                                radius: 24,
                                backgroundImage: NetworkImage(
                                    'https://via.placeholder.com/150'), // Replace with organizer's image URL
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    organizerName,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    organizerLocation,
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Description:",
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            campaignData['description'] ?? 'No description available.',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Raised: \$${raised.toStringAsFixed(2)} / Goal: \$${goal.toStringAsFixed(2)}",
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.grey[300],
                            color: const Color(0xFF3EB489),
                            minHeight: 12,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Remaining: \$${remainingAmount.toStringAsFixed(2)}",
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton(
                      onPressed: () {
                        _showDonationDialog(remainingAmount, widget.campaignId, userId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3EB489),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text(
                        "Donate Now",
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
