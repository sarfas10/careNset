

import 'dart:io';
// ignore: unused_import
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:care_nest/stripeSecretKey.dart';

class AddCampaignPage extends StatefulWidget {
  @override
  _AddCampaignPageState createState() => _AddCampaignPageState();
}

class _AddCampaignPageState extends State<AddCampaignPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _locationController = TextEditingController();
  final _categoryController = TextEditingController();

  final _picker = ImagePicker();
  final _firestore = FirebaseFirestore.instance;

  dynamic _thumbnailFile;
  bool _isLoading = false;
  bool _isOrganiser = false;
  bool _isFetchingUserStatus = true;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _checkOrganiserStatus();
  }

  Future<void> _checkOrganiserStatus() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception("User not logged in");

      final userDoc = await _firestore.collection('users').doc(userId).get();
      setState(() {
        _isOrganiser = userDoc.data()?['organiser'] == 'yes';
        _isFetchingUserStatus = false;
      });
    } catch (e) {
      setState(() => _isFetchingUserStatus = false);
      _showSnackBar("Error checking organiser status: $e");
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        if (kIsWeb) {
          _thumbnailFile = await pickedFile.readAsBytes();
        } else {
          _thumbnailFile = File(pickedFile.path);
        }
        setState(() {});
      } else {
        _showSnackBar('No image selected');
      }
    } catch (e) {
      _showSnackBar('Error picking image: $e');
    }
  }

  Future<String> _uploadToCloudinary(dynamic imageFile) async {
    const cloudName = "dxeunc4vd";
    const uploadPreset = "careNest";
    const cloudinaryUrl = "https://api.cloudinary.com/v1_1/$cloudName/image/upload";

    try {
      final request = http.MultipartRequest('POST', Uri.parse(cloudinaryUrl))
        ..fields['upload_preset'] = uploadPreset;

      if (kIsWeb) {
        request.files.add(http.MultipartFile.fromBytes('file', imageFile, filename: 'campaign_image.jpg'));
      } else {
        request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
      }

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final jsonData = json.decode(responseData);
        return jsonData['secure_url'];
      } else {
        throw Exception("Failed to upload image to Cloudinary");
      }
    } catch (e) {
      throw Exception("Error uploading image: $e");
    }
  }

  Future<void> _saveCampaignDetails() async {
    setState(() => _isLoading = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception("User not logged in");

      // Ensure the user has a Stripe account ID
      final userDoc = await _firestore.collection('users').doc(userId).get();
      String? stripeAccountId = userDoc.data()?['stripeAccountId'];

      

      // Upload the image
      String? imageUrl;
      if (_thumbnailFile != null) {
        imageUrl = await _uploadToCloudinary(_thumbnailFile);
      }

      // Validate and fetch category
      final categoryName = _categoryController.text.trim();
      if (categoryName.isEmpty) throw Exception("Category cannot be empty");

      final categorySnapshot = await _firestore
          .collection('categories')
          .where('name', isEqualTo: categoryName)
          .get();

      String categoryId;
      if (categorySnapshot.docs.isEmpty) {
        final newCategory = await _firestore.collection('categories').add({'name': categoryName});
        categoryId = newCategory.id;
      } else {
        categoryId = categorySnapshot.docs.first.id;
      }

      // Save campaign details
      await _firestore.collection('campaigns').add({
        'title': _titleController.text,
        'description': _descriptionController.text,
        'amount': double.parse(_amountController.text),
        'location': _locationController.text,
        'category_id': categoryId,
        'image_url': imageUrl,
        'user_id': userId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _showSnackBar("Campaign successfully created!");
      _resetForm();
    } catch (e) {
      _showSnackBar('Error saving campaign: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

 

 void _nextStep() async {
  if (_currentStep < 2) {
    setState(() => _currentStep++);
  } else {
    if (_isOrganiser) {
      try {
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId == null) throw Exception("User not logged in");

        final userDoc = await _firestore.collection('users').doc(userId).get();
        

        
          await _saveCampaignDetails();
        
      } catch (e) {
        _showSnackBar("Error: $e");
      }
    }
  }
}


  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  void _resetForm() {
    setState(() {
      _titleController.clear();
      _descriptionController.clear();
      _amountController.clear();
      _locationController.clear();
      _categoryController.clear();
      _thumbnailFile = null;
      _currentStep = 0;
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Start Campaign"), centerTitle: true),
      body: _isFetchingUserStatus
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_isOrganiser)
                    Container(
                      padding: EdgeInsets.all(12),
                      color: Colors.red.shade100,
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.red),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "You need to setup complete your organiser KYC to post a campaign.",
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStepIndicator("Details", _currentStep >= 0),
                      Expanded(
                        child: Container(
                          height: 2,
                          color: _currentStep >= 1 ? Color(0xFF3EB489) : Colors.grey,
                        ),
                      ),
                      _buildStepIndicator("Setup", _currentStep >= 1),
                      Expanded(
                        child: Container(
                          height: 2,
                          color: _currentStep >= 2 ? Color(0xFF3EB489) : Colors.grey,
                        ),
                      ),
                      _buildStepIndicator("Photo", _currentStep >= 2),
                    ],
                  ),
                  SizedBox(height: 30),
                  if (_currentStep == 0) _buildDetailsSection(),
                  if (_currentStep == 1) _buildSetupSection(),
                  if (_currentStep == 2) _buildPhotoSection(),
                  SizedBox(height: 30),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_currentStep > 0)
                          ElevatedButton(
                            onPressed: _previousStep,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              minimumSize: Size(100, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                            child: Text("Back", style: TextStyle(fontSize: 16)),
                          ),
                        SizedBox(width: 20),
                        _isLoading
                            ? CircularProgressIndicator()
                            : ElevatedButton(
                                onPressed: _isOrganiser ? _nextStep : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isOrganiser
                                      ? Color(0xFF3EB489)
                                      : Colors.grey,
                                  minimumSize: Size(150, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                ),
                                child: Text(
                                  _currentStep < 2 ? "Continue" : "Finish",
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

 Widget _buildStepIndicator(String label, bool isActive) {
    return Column(
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: isActive ? Color(0xFF3EB489) : Colors.grey,
          child: Text(
            ("DetailsSetupPhoto".split(label).first.length ~/ 5 + 1).toString(),
            style: TextStyle(color: Colors.white),
          ),
        ),
        SizedBox(height: 4),
        Text(label, style: TextStyle(color: isActive ? Color(0xFF3EB489) : Colors.grey)),
      ],
    );
  }

  Widget _buildDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Fundraiser Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 20),
        TextField(
          controller: _amountController,
          decoration: InputDecoration(
            labelText: "How much would you like to raise?",
            prefixText: "\$ ",
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        SizedBox(height: 16),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: "Choose Category",
            border: OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(value: "Education", child: Text("Education")),
            DropdownMenuItem(value: "Medical", child: Text("Medical")),
            DropdownMenuItem(value: "Environment", child: Text("Environment")),
          ],
          onChanged: (value) {
            _categoryController.text = value ?? "";
          },
        ),
        SizedBox(height: 16),
        TextField(
          controller: _locationController,
          decoration: InputDecoration(
            labelText: "Location",
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildSetupSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Campaign Setup", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 20),
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: "Campaign Title",
            border: OutlineInputBorder(),
          ),
        ),
        SizedBox(height: 16),
        TextField(
          controller: _descriptionController,
          decoration: InputDecoration(
            labelText: "Campaign Description",
            border: OutlineInputBorder(),
          ),
          maxLines: 5,
        ),
      ],
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Add Campaign Photo", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 20),
        if (_thumbnailFile != null)
          (kIsWeb
              ? Image.memory(_thumbnailFile, height: 200, fit: BoxFit.cover)
              : Image.file(_thumbnailFile, height: 200, fit: BoxFit.cover)),
        SizedBox(height: 16),
        ElevatedButton(
          onPressed: _pickImage,
          child: Text("Select Image"),
        ),
      ],
    );
  }
}