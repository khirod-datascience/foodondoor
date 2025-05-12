import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/customer_provider.dart';

class ProfileEditScreen extends StatefulWidget {
  final String customerId;
  const ProfileEditScreen({Key? key, required this.customerId}) : super(key: key);
  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  String? name, email, phone;
  bool deleting = false;

  @override
  void initState() {
    super.initState();
    Provider.of<CustomerProvider>(context, listen: false).fetchProfile(widget.customerId);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CustomerProvider>(context);
    final profile = provider.profile;
    return Scaffold(
      appBar: AppBar(title: Text('Edit Profile')),
      body: provider.loadingProfile
          ? Center(child: CircularProgressIndicator())
          : profile == null
              ? Center(child: Text('Profile not found'))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          initialValue: profile['full_name'] ?? '',
                          decoration: InputDecoration(labelText: 'Name'),
                          onSaved: (v) => name = v,
                        ),
                        TextFormField(
                          initialValue: profile['email'] ?? '',
                          decoration: InputDecoration(labelText: 'Email'),
                          onSaved: (v) => email = v,
                        ),
                        TextFormField(
                          initialValue: profile['phone'] ?? '',
                          decoration: InputDecoration(labelText: 'Phone'),
                          onSaved: (v) => phone = v,
                        ),
                        SizedBox(height: 20),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: () async {
                                _formKey.currentState?.save();
                                await provider.updateProfile(widget.customerId, {
                                  'full_name': name ?? profile['full_name'],
                                  'email': email ?? profile['email'],
                                  'phone': phone ?? profile['phone'],
                                });
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Profile updated!')));
                              },
                              child: Text('Save'),
                            ),
                            SizedBox(width: 20),
                            if (!deleting)
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                onPressed: () async {
                                  setState(() => deleting = true);
                                  await provider.deleteProfile(widget.customerId);
                                  setState(() => deleting = false);
                                  Navigator.of(context).pop();
                                },
                                child: Text('Delete'),
                              ),
                            if (deleting) CircularProgressIndicator(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
