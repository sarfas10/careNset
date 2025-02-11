import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

class KYCFormPage extends StatefulWidget {
  @override
  _KYCFormPageState createState() => _KYCFormPageState();
}

class _KYCFormPageState extends State<KYCFormPage> {
  int _currentStep = 0;

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
final _nationalityController = TextEditingController();

  final _pincodeController = TextEditingController();

  Uint8List? _idProofBytes;
  // ignore: unused_field
  String? _fileExtension;
  String? _documentType;
 

  // Cloudinary Config
  final String cloudinaryUploadPreset = "careNest";
  final String cloudinaryCloudName = "dxeunc4vd";

  Future<void> _pickIDProof() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'png', 'jpeg', 'pdf'], // Specify allowed extensions
      );
      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _idProofBytes = result.files.single.bytes;
          _fileExtension = result.files.single.extension; // Store file extension
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("File selected successfully.")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No file selected.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error picking file: $e")),
      );
    }
  }

Future<String?> _uploadToCloudinary(Uint8List fileBytes) async {
  try {
    final uri = Uri.parse(
        "https://api.cloudinary.com/v1_1/$cloudinaryCloudName/image/upload");

    final request = http.MultipartRequest('POST', uri);

    // Set the upload preset
    request.fields['upload_preset'] = cloudinaryUploadPreset;

    // Add the file as bytes with the correct content type
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: 'upload.jpg',  // You can update the filename as necessary
      ),
    );

    // Send the request
    final response = await request.send();

    final responseBody = await response.stream.bytesToString();
    if (response.statusCode == 200) {
      final Map<String, dynamic> responseMap = jsonDecode(responseBody);
      return responseMap['secure_url'];
    } else {
      print("Cloudinary upload failed with status ${response.statusCode}");
      print("Response body: $responseBody");
      return null;
    }
  } catch (e) {
    print("Error uploading to Cloudinary: $e");
    return null;
  }
}

  bool _isImageFile() {
    return _fileExtension == 'jpg' || _fileExtension == 'jpeg' || _fileExtension == 'png';
  }

  // Step 3 - Upload KYC data to Firestore
  Future<void> _uploadKYC() async {
    try {
      // Get the current user ID (logged-in user's UID)
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // If the user is not logged in, handle accordingly
        print("No user is logged in");
        return;
      }
      String userId = user.uid; // Current user ID

      // Get the KYC data
      String name = _nameController.text;
      String address = _addressController.text;
      String nationality = _nationalityController.text;
      String pincode = _pincodeController.text;
      String documentType = _documentType ?? "No Document Selected";
      

      // Ensure we have selected an ID proof file
      if (_idProofBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please upload an ID proof")),
        );
        return;
      }

      // Upload the ID proof to Cloudinary
      String? imageUrl = await _uploadToCloudinary(_idProofBytes!);

      if (imageUrl != null) {
        // Prepare the KYC data to be uploaded
        Map<String, dynamic> kycData = {
          'userId': userId, // Store current logged-in user ID
          'name': name,
          'address': address,
          'nationality': nationality,
          'pincode': pincode,
          'documentType': documentType,
          
          'idProofUrl': imageUrl, // Store the ID proof URL from Cloudinary
          'timestamp': FieldValue.serverTimestamp(),
          'status': "pending", // Add a timestamp for when the data was uploaded
        };

        // Upload to Firestore (to the 'verification' collection)
        await FirebaseFirestore.instance.collection('verification').add(kycData);

        // Optionally, show a success message or navigate away
        print("KYC data uploaded successfully.");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("KYC submitted successfully!")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to upload ID proof")),
        );
      }
    } catch (e) {
      print("Error uploading KYC: $e");
      // Handle error (e.g., show a message to the user)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error submitting KYC: $e")),
      );
    }
  }


  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.green[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 15),
    );
  }

  Widget _buildProgressBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildProgressStep(0, "Personal Details"),
        _buildProgressStep(1, "ID Proof"),
        
      ],
    );
  }

  Widget _buildProgressStep(int step, String label) {
    bool isCompleted = step <= _currentStep;
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: isCompleted ? Colors.green : Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                "${step + 1}",
                style: TextStyle(
                  color: isCompleted ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isCompleted ? Colors.green : Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          if (step < 2) ...[
            SizedBox(height: 10),
            Container(
              height: 2,
              color: isCompleted ? Colors.green : Colors.grey[300],
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
     
      default:
        return _buildStep1();
    }
  }

  Widget _buildStep1() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        "Enter Your Details",
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      SizedBox(height: 10),
      TextFormField(
        controller: _nameController,
        decoration: _inputDecoration("Name"),
      ),
      SizedBox(height: 15),
      TextFormField(
        controller: _addressController,  // New address controller
        decoration: _inputDecoration("Address"),
        keyboardType: TextInputType.streetAddress,
      ),
      SizedBox(height: 15),
      TextFormField(
        controller: _nationalityController,  // New nationality controller
        decoration: _inputDecoration("Nationality"),
      ),
      SizedBox(height: 15),
      TextFormField(
        controller: _pincodeController,
        decoration: _inputDecoration("Pincode"),
        keyboardType: TextInputType.number,
      ),
    ],
  );
}


  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Choose Document Type",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ChoiceChip(
              label: Text("Aadhaar Card"),
              selected: _documentType == "Aadhaar Card",
              onSelected: (selected) {
                setState(() {
                  _documentType = selected ? "Aadhaar Card" : null;
                });
              },
            ),
            ChoiceChip(
              label: Text("Pan Card"),
              selected: _documentType == "Pan Card",
              onSelected: (selected) {
                setState(() {
                  _documentType = selected ? "Pan Card" : null;
                });
              },
            ),
            ChoiceChip(
              label: Text("Driving License"),
              selected: _documentType == "Driving License",
              onSelected: (selected) {
                setState(() {
                  _documentType = selected ? "Driving License" : null;
                });
              },
            ),
          ],
        ),
        SizedBox(height: 15),
        ElevatedButton(
          onPressed: _pickIDProof,
          child: Text(_idProofBytes == null ? "Upload ID Proof" : "File Selected"),
        ),
        SizedBox(height: 15),
        if (_idProofBytes != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Preview:",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              if (_isImageFile())
                Image.memory(
                  _idProofBytes!,
                  height: 200,
                  fit: BoxFit.cover,
                )
              else
                Container(
                  padding: EdgeInsets.all(10),
                  color: Colors.grey[200],
                  child: Text(
                    "File Preview: This is not an image file.",
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
            ],
          ),
      ],
    );
  }

 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Upload KYC")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildProgressBar(),
            SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: _buildStepContent(),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentStep > 0)
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _currentStep -= 1;
                      });
                    },
                    child: Text("Back"),
                  ),
                ElevatedButton(
                  onPressed: () {
                    if (_currentStep < 1) {
                      setState(() {
                        _currentStep += 1;
                      });
                    } else {
                      _uploadKYC();
                    }
                  },
                  child: Text(_currentStep == 1 ? "Submit" : "Next"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
