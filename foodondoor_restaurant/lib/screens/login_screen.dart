import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../globals.dart';

class LoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Vendor ID',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                // Store the vendor ID temporarily
                Globals.vendorId = value;
              },
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (Globals.vendorId != null && Globals.vendorId!.isNotEmpty) {
                  context.read<AuthService>().login(Globals.vendorId!);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please enter a valid Vendor ID')),
                  );
                }
              },
              child: Text('Login'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 