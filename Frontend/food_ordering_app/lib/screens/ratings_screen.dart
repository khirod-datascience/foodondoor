import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/rating_provider.dart';

class RatingsScreen extends StatefulWidget {
  @override
  State<RatingsScreen> createState() => _RatingsScreenState();
}

class _RatingsScreenState extends State<RatingsScreen> {
  final _formKey = GlobalKey<FormState>();
  String? ratingText;
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RatingProvider>(context);
    return Scaffold(
      appBar: AppBar(title: Text('Submit Rating')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: 'Your rating/comments'),
                onSaved: (v) => ratingText = v,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: provider.submitting
                    ? null
                    : () {
                        _formKey.currentState?.save();
                        provider.submitRating({'text': ratingText ?? ''});
                      },
                child: Text('Submit'),
              ),
              if (provider.submitting) CircularProgressIndicator(),
              if (provider.message != null) Text(provider.message!),
            ],
          ),
        ),
      ),
    );
  }
}
