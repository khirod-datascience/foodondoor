import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/promotion_provider.dart';

class PromotionsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PromotionProvider>(context);
    return Scaffold(
      appBar: AppBar(title: Text('Promotions')),
      body: provider.loading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: provider.promotions.length,
              itemBuilder: (context, i) {
                final promo = provider.promotions[i];
                return ListTile(
                  title: Text(promo['title'] ?? ''),
                  subtitle: Text(promo['description'] ?? ''),
                );
              },
            ),
    );
  }
}
