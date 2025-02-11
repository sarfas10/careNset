import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WalletPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {

      
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Wallet')),
        body: const Center(
          child: Text('User not logged in.'),
        ),
      );
    }

    String userId = currentUser.uid;

    return Scaffold(
      body: WalletBody(userId: userId),
    );
  }
}

class WalletBody extends StatefulWidget {
  final String userId;

  const WalletBody({required this.userId});

  @override
  State<WalletBody> createState() => _WalletBodyState();
}

class _WalletBodyState extends State<WalletBody> {
  bool isBalanceVisible = true;

  @override
  void initState() {
    super.initState();
    _loadVisibilityState();
  }

void _showPayoutDrawer(BuildContext context, String userId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent, // Make the modal's background transparent
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.6, // 60% of screen height
        minChildSize: 0.5, // Minimum 50%
        maxChildSize: 0.6, // Maximum 60%
        builder: (_, controller) {
          return Material(
            color: Colors.white, // Use Material to apply elevation and color
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            child: Column(
              children: [
                // Optional: Add a drag handle
                Container(
                  width: 40,
                  height: 5,
                  margin: EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Expanded(
                  child: PayoutDrawer(
                    userId: userId,
                    scrollController: controller,
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}


  Future<void> _loadVisibilityState() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      isBalanceVisible = prefs.getBool('isBalanceVisible') ?? true;
    });
  }

  Future<void> _saveVisibilityState(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('isBalanceVisible', value);
  }

  Future<Map<String, double>> fetchGrowthData() async {
    final walletHistoryDoc = FirebaseFirestore.instance
        .collection('walletHistory')
        .doc(widget.userId);

    final latestDoc = await walletHistoryDoc.get();

    if (!latestDoc.exists) {
      return {'growthAmount': 0.0, 'growthPercentage': 0.0};
    }

    final growthAmount = (latestDoc.data()?['amount'] as num?)?.toDouble() ?? 0.0;
    final currentBalance = (await FirebaseFirestore.instance
            .collection('wallet')
            .doc(widget.userId)
            .get())
        .data()?['balance'] as num? ??
        0.0;

    final growthPercentage =
        currentBalance > 0 ? (growthAmount / currentBalance) * 100 : 0.0;

    return {'growthAmount': growthAmount, 'growthPercentage': growthPercentage};
  }

  Stream<QuerySnapshot> fetchTransactions() {
  return FirebaseFirestore.instance
      .collection('walletHistory') // Reference to walletHistory collection
      .where(FieldPath.documentId, isEqualTo: widget.userId) // Filter by userId
      .orderBy('timestamp', descending: true) // Sort by timestamp
      .snapshots(); // Return a stream of snapshots
}


  Future<String> _getTransactionTitle(String flowType, String flowId) async {
    try {
      if (flowType == 'in') {
        final donationDoc = await FirebaseFirestore.instance
            .collection('donations')
            .doc(flowId)
            .get();

        if (!donationDoc.exists) return 'Unknown User';

        final donorId = donationDoc.data()?['donorId'] as String? ?? '';
        if (donorId.isEmpty) return 'Unknown User';

        final campaignDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(donorId)
            .get();

        return campaignDoc.data()?['name'] as String? ?? 'Unknown User';
      } else if (flowType == 'out') {
        return 'Payout';
      }
    } catch (e) {
      return 'Error fetching title';
    }

    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    CollectionReference users = FirebaseFirestore.instance.collection('users');
    CollectionReference wallets = FirebaseFirestore.instance.collection('wallet');

    return FutureBuilder<Map<String, double>>(
      future: fetchGrowthData(),
      builder: (context, growthSnapshot) {
        if (growthSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (growthSnapshot.hasError || !growthSnapshot.hasData) {
          return const Center(
            child: Text('Failed to load growth data.'),
          );
        }

        final growthData = growthSnapshot.data!;
        final growthAmount = growthData['growthAmount']!;
        final growthPercentage = growthData['growthPercentage']!;

        return FutureBuilder<DocumentSnapshot>(
          future: users.doc(widget.userId).get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return const Center(child: Text('User data not found.'));
            }

            String userName = userSnapshot.data!['name'];

            return FutureBuilder<DocumentSnapshot>(
              future: wallets.doc(widget.userId).get(),
              builder: (context, walletSnapshot) {
                if (walletSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!walletSnapshot.hasData || !walletSnapshot.data!.exists) {
                  return const Center(child: Text('Wallet data not found.'));
                }

                double walletAmount = walletSnapshot.data!['balance'] ?? 0.0;

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      StatefulBuilder(
                        builder: (context, setState) {
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16.0),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(16.0),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Your Balance',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 16,
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            isBalanceVisible
                                                ? Icons.visibility
                                                : Icons.visibility_off,
                                            color: Colors.white70,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              isBalanceVisible = !isBalanceVisible;
                                              _saveVisibilityState(isBalanceVisible);
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      isBalanceVisible
                                          ? '\$${walletAmount.toStringAsFixed(2)}'
                                          : '*****',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0,
                                        vertical: 4.0,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.greenAccent,
                                        borderRadius: BorderRadius.circular(8.0),
                                      ),
                                      child: Text(
                                        '+\$${growthAmount.toStringAsFixed(0)} • $growthPercentage%',
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                bottom: 18,
                                right: 18,
                                child: Icon(
                                  Icons.auto_awesome,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          _showPayoutDrawer(context, widget.userId);
                        },
                        child: const Text('Request Payout',style: TextStyle(
                                    color: Colors.white,
                                  ),),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Transactions',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: fetchTransactions(),
                          builder: (context, transactionSnapshot) {
                            if (transactionSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (!transactionSnapshot.hasData ||
                                transactionSnapshot.data!.docs.isEmpty) {
                              return const Center(
                                child: Text(
                                  'No transactions to display.',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              );
                            }

                            final transactions = transactionSnapshot.data!.docs;

                            return ListView.builder(
                              itemCount: transactions.length,
                              itemBuilder: (context, index) {
                                final transaction = transactions[index].data()
                                    as Map<String, dynamic>;

                                final flowType = transaction['flow'] as String? ?? 'out';
                                final flowId = transaction['flowId'] as String? ?? '';
                                final amount = transaction['amount'] as num? ?? 0.0;
                                final date = (transaction['date'] as Timestamp?)?.toDate() ?? DateTime.now();

                                return FutureBuilder<String>(
                                  future: _getTransactionTitle(flowType, flowId),
                                  builder: (context, titleSnapshot) {
                                    if (titleSnapshot.connectionState == ConnectionState.waiting) {
                                      return const ListTile(
                                        title: Text('Loading...'),
                                        subtitle: Text('Please wait'),
                                      );
                                    }
                                    if (titleSnapshot.hasError || !titleSnapshot.hasData) {
                                      return const ListTile(
                                        title: Text('Error fetching details'),
                                      );
                                    }

                                    final title = titleSnapshot.data!;

                                    return ListTile(
                                      title: Text(title,style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),),
                                      subtitle: Text(
                                        '${date.toLocal()}'.split(' ')[0],
                                      ),
                                      trailing: Text(
                                        (flowType == 'in' ? '+' : '-') + '\$${amount.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: flowType == 'in' ? Colors.green : Colors.red,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
  
}
class PayoutDrawer extends StatefulWidget {
  final String userId;
  final ScrollController? scrollController;
  const PayoutDrawer({required this.userId, this.scrollController});

  @override
  State<PayoutDrawer> createState() => _PayoutDrawerState();
}

class _PayoutDrawerState extends State<PayoutDrawer> {
  String? payoutMethod;
  String? upiId;
  String? bankAccountNumber;
  String? bankName;
  String? bankBranch;
  String? ifscCode;
  String? qrImageUrl;
  double? payoutAmount;
  PlatformFile? selectedQrFile;

  final TextEditingController upiIdController = TextEditingController();
  final TextEditingController payoutAmountController = TextEditingController();

  bool isUploading = false;

  Future<void> _uploadQrCode(PlatformFile file) async {
    try {
      setState(() {
        isUploading = true;
        selectedQrFile = file;
      });

      final cloudinaryUrl = "https://api.cloudinary.com/v1_1/dxeunc4vd/image/upload";
      final uploadPreset = "careNest";

      final request = http.MultipartRequest("POST", Uri.parse(cloudinaryUrl));
      request.fields['upload_preset'] = uploadPreset;

      if (file.bytes != null) {
        // Use bytes for web
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          file.bytes!,
          filename: file.name,
        ));
      } else if (file.path != null) {
        // Use file path for mobile/desktop
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          file.path!,
        ));
      } else {
        throw Exception('File data is not available');
      }

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonResponse = json.decode(responseData);
        setState(() {
          qrImageUrl = jsonResponse['secure_url'];
        });
      } else {
        throw Exception('Failed to upload QR code');
      }
    } catch (e) {
      print('Error uploading QR code: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload QR code: $e')),
      );
    } finally {
      setState(() {
        isUploading = false;
      });
    }
  }

  Future<void> _savePayoutRequest() async {
    final firestore = FirebaseFirestore.instance;

    final payoutData = {
      'userId': widget.userId,
      'payoutMethod': payoutMethod,
      'upiId': upiId,
      'qrImageUrl': qrImageUrl,
      'bankAccountNumber': bankAccountNumber,
      'bankName': bankName,
      'bankBranch': bankBranch,
      'ifscCode': ifscCode,
      'amount': payoutAmount,
      'requestedAt': Timestamp.now(),
    };

    await firestore.collection('payoutRequests').add(payoutData);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payout request submitted!')),
    );

    Navigator.pop(context);
  }

  int currentStep = 1;

  void _goToPreviousStep() {
    setState(() {
      if (currentStep > 1) {
        currentStep--;
      }
    });
  }
  Future<void> _showConfirmationDialog() async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Payout Request'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Are you sure you want to submit this payout request?'),
              SizedBox(height: 10),
              Text('Payout Method: ${payoutMethod == 'upi' ? 'UPI' : 'Bank Transfer'}'),
              Text('Amount: ₹${payoutAmount?.toStringAsFixed(2) ?? ''}'),
              if (payoutMethod == 'upi') ...[
                Text('UPI ID: $upiId'),
                if (qrImageUrl != null)
                  Text('QR Code: Uploaded'),
              ] else ...[
                Text('Bank Account Number: $bankAccountNumber'),
                Text('Bank Name: $bankName'),
                Text('Bank Branch: $bankBranch'),
                Text('IFSC Code: $ifscCode'),
              ],
            ],
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            ElevatedButton(
              child: Text('Confirm'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _savePayoutRequest();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Payout Request'),
        leading: currentStep > 1 
          ? IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: _goToPreviousStep,
            )
          : null,
      ),
      body: SingleChildScrollView(
        controller: widget.scrollController,
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (currentStep == 1) ...[
              Text(
                'Choose Payout Method',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              Card(
                elevation: 2,
                child: Column(
                  children: [
                    RadioListTile(
                      title: Text('UPI'),
                      value: 'upi',
                      groupValue: payoutMethod,
                      onChanged: (value) {
                        setState(() {
                          payoutMethod = value.toString();
                        });
                      },
                    ),
                    RadioListTile(
                      title: Text('Bank Transfer'),
                      value: 'bank',
                      groupValue: payoutMethod,
                      onChanged: (value) {
                        setState(() {
                          payoutMethod = value.toString();
                        });
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  minimumSize: Size(double.infinity, 50),
                ),
                onPressed: payoutMethod != null
                    ? () {
                        setState(() {
                          currentStep = 2;
                        });
                      }
                    : null,
                child: Text('Next'),
              ),
            ],

            if (currentStep == 2) ...[
              if (payoutMethod == 'upi') ...[
                TextField(
                  controller: upiIdController,
                  decoration: InputDecoration(
                    labelText: 'Enter UPI ID',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    upiId = value;
                  },
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                  ),
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(type: FileType.image);
                    if (result != null) {
                      final file = result.files.first;
                      await _uploadQrCode(file);
                    }
                  },
                  child: isUploading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text('Upload QR Code (Optional)'),
                ),
                if (selectedQrFile != null || qrImageUrl != null) ...[
                  SizedBox(height: 10),
                  Text(
                    'QR Code Preview',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: selectedQrFile?.bytes != null
                          ? Image.memory(
                              selectedQrFile!.bytes!, 
                              height: 200, 
                              width: double.infinity,
                              fit: BoxFit.contain,
                            )
                          : (qrImageUrl != null
                              ? Image.network(
                                  qrImageUrl!, 
                                  height: 200, 
                                  width: double.infinity,
                                  fit: BoxFit.contain,
                                )
                              : Container()),
                    ),
                  ),
                ],
              ],
              if (payoutMethod == 'bank') ...[
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Account Number',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    bankAccountNumber = value;
                  },
                ),
                SizedBox(height: 10),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Bank Name',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    bankName = value;
                  },
                ),
                SizedBox(height: 10),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Bank Branch',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    bankBranch = value;
                  },
                ),
                SizedBox(height: 10),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'IFSC Code',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    ifscCode = value;
                  },
                ),
              ],
              SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  minimumSize: Size(double.infinity, 50),
                ),
                onPressed: () {
                  setState(() {
                    currentStep = 3;
                  });
                },
                child: Text('Next'),
              ),
            ],

            if (currentStep == 3) ...[
              Text(
                'Enter Amount',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              TextField(
                controller: payoutAmountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                  prefixText: '₹ ',
                ),
                onChanged: (value) {
                  payoutAmount = double.tryParse(value);
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  minimumSize: Size(double.infinity, 50),
                ),
                onPressed: () {
                  setState(() {
                    currentStep = 4;
                  });
                },
                child: Text('Next'),
              ),
            ],
             if (currentStep == 4) ...[
              Text(
                'Review Your Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payout Method',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(payoutMethod == 'upi' ? 'UPI' : 'Bank Transfer'),
                      SizedBox(height: 10),
                      
                      Text(
                        'Amount',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('₹${payoutAmount?.toStringAsFixed(2) ?? ''}'),
                      SizedBox(height: 10),
                      
                      if (payoutMethod == 'upi') ...[
                        Text(
                          'UPI Details',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('UPI ID: $upiId'),
                        
                        if (qrImageUrl != null || selectedQrFile != null) ...[
                          SizedBox(height: 10),
                          Text(
                            'QR Code',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Card(
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: selectedQrFile?.bytes != null
                                  ? Image.memory(
                                      selectedQrFile!.bytes!, 
                                      height: 200, 
                                      width: double.infinity,
                                      fit: BoxFit.contain,
                                    )
                                  : (qrImageUrl != null
                                      ? Image.network(
                                          qrImageUrl!, 
                                          height: 200, 
                                          width: double.infinity,
                                          fit: BoxFit.contain,
                                        )
                                      : Container()),
                            ),
                          ),
                        ],
                      ] else ...[
                        Text(
                          'Bank Details',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('Account Number: $bankAccountNumber'),
                        Text('Bank Name: $bankName'),
                        Text('Bank Branch: $bankBranch'),
                        Text('IFSC Code: $ifscCode'),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  minimumSize: Size(double.infinity, 50),
                ),
                onPressed: () {
                  _showConfirmationDialog();
                },
                child: Text('Submit Payout Request'),
              ),
            ],
         

          ],
        ),
      ),
    );
  }
}

