import 'package:shared_preferences/shared_preferences.dart'; // Import shared preferences
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../globals.dart'; // Import the global file
import '../config.dart';
import 'login_signup_screen.dart'; // Import the login/signup screen

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      print("Fetching profile for vendor: ${Globals.vendorId}");
      final response = await http.get(
        Uri.parse('${Config.baseUrl}/auth/profile/${Globals.vendorId}/'),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print("Profile response: $responseData"); // Debug print
        print("Uploaded images: ${responseData['uploaded_images']}"); // Debug print

        setState(() {
          _profile = responseData;
        });
      } else {
        print("Failed to fetch profile: ${response.statusCode} - ${response.body}"); // Debug print
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to fetch profile: ${response.statusCode}")),
        );
      }
    } catch (e) {
      print("Network error: $e"); // Debug print
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Network error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Profile"),
        backgroundColor: Colors.orange,
      ),
      body: Container(
        color: Colors.orange[50],
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _profile == null
              ? Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Header
                      Center(
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.orange,
                              child: Icon(Icons.store, size: 50, color: Colors.white),
                            ),
                            SizedBox(height: 16),
                            Text(
                              _profile!['restaurant_name'],
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24),

                      // Profile Details
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildProfileRow(Icons.email, "Email", _profile!['email']),
                              SizedBox(height: 16),
                              _buildProfileRow(Icons.phone, "Phone", _profile!['phone']),
                              SizedBox(height: 16),
                              _buildProfileRow(Icons.location_on, "Address", _profile!['address']),
                              SizedBox(height: 16),
                              _buildProfileRow(Icons.contact_phone, "Contact Number", _profile!['contact_number']),
                              SizedBox(height: 16),
                              _buildProfileRow(Icons.access_time, "Open Hours", _profile!['open_hours']), // Open Hours
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 24),

                      // Uploaded Images Section
                      Text(
                        "Uploaded Images",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                      SizedBox(height: 8),
                      _profile!['uploaded_images'].isEmpty
                          ? Text("No images uploaded", style: TextStyle(fontSize: 16))
                          : Wrap(
                              spacing: 8,
                              children: (_profile!['uploaded_images'] as List<dynamic>).map((imageUrl) {
                                print("Processing image URL: ${Config.baseUrl}$imageUrl"); // Debug print
                                return Container(
                                  width: 100,
                                  height: 100,
                                  margin: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.orange.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      '${Config.baseUrl}$imageUrl'.replaceAll('\\', '/'), // Fix backslash issue
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return Center(
                                          child: CircularProgressIndicator(
                                            value: loadingProgress.expectedTotalBytes != null
                                                ? loadingProgress.cumulativeBytesLoaded /
                                                    loadingProgress.expectedTotalBytes!
                                                : null,
                                          ),
                                        );
                                      },
                                      errorBuilder: (context, error, stackTrace) {
                                        print("Error loading image: $error"); // Debug print
                                        print("Failed URL: ${Config.baseUrl}$imageUrl"); // Debug print
                                        return Container(
                                          color: Colors.grey[200],
                                          child: Icon(Icons.broken_image, color: Colors.grey),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                      SizedBox(height: 24),

                      // Logout Button
                      Center(
                        child: ElevatedButton(
                          onPressed: () async {
                            // Clear session or token here
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.clear(); // Clear all stored data

                            // Navigate to login screen
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => LoginSignupScreen()),
                            );
                          },
                          child: Text("Logout"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                            textStyle: TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildProfileRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.orange),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            "$label: $value",
            style: TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }
}
