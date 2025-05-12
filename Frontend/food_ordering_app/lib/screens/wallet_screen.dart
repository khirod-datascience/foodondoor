import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';

class WalletScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<WalletProvider>(context);
    return Scaffold(
      appBar: AppBar(title: Text('Wallet')),
      body: provider.loading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Text('Balance: ₹${provider.balance.toStringAsFixed(2)}'),
                Expanded(
                  child: ListView.builder(
                    itemCount: provider.transactions.length,
                    itemBuilder: (context, i) {
                      final tx = provider.transactions[i];
                      return ListTile(
                        title: Text('Txn: ${tx['id'] ?? ''}'),
                        subtitle: Text('${tx['amount'] ?? ''}'),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
