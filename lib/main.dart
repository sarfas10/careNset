import 'package:care_nest/admin_dashboard.dart';
import 'package:care_nest/firebase_options.dart'; // Generated Firebase options
import 'package:care_nest/login.dart';
import 'package:care_nest/onboard.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:care_nest/stripeSecretKey.dart'; // Stripe keys
import 'package:care_nest/user_home_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:get/get.dart';
// To handle deep links

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Stripe
  await _setup();

  // Set URL strategy for deep linking (if needed)
  

  runApp(const MyApp());
}

// Stripe setup with publishable key
Future<void> _setup() async {
  Stripe.publishableKey = stripePublishableKey; // Ensure this key is defined in stripeSecretKey.dart
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Care Nest App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true, // Opt-in to Material 3
      ),
      debugShowCheckedModeBanner: false,

      // Define the initial route
      home: AuthWrapper(),
      routes: {
        
        '/home': (context) => UserHomePage(),
        '/login': (context) => Onboard(),
        
    
      },
    );
  }
}


class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(), // Listen for auth changes
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasData) {
          // User is logged in; check their role
          final user = snapshot.data!;
          return FutureBuilder<String?>(
            future: getUserRole(user.uid), // Fetch the role from Firestore
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (roleSnapshot.hasData) {
                final role = roleSnapshot.data;
                if (role == 'admin') {
                  return AdminDashboard(); // Navigate to Admin Dashboard
                } else {
                  return UserHomePage(); // Navigate to User Home Page
                }
              }
              // Handle errors or no role data
              return Center(child: Text('Error fetching user role'));
            },
          );
        }
        // User is not logged in
        return Onboard();
      },
    );
  }

  // Function to fetch user role from Firestore
  Future<String?> getUserRole(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data()?['role'] as String?; // Access the 'role' field
      }
      return null; // No role found
    } catch (e) {
      print('Error fetching user role: $e');
      return null;
    }
  }
}

