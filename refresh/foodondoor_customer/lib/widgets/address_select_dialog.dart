import 'package:flutter/material.dart';

class AddressSelectDialog extends StatelessWidget {
  final List<Map<String, dynamic>> addresses;
  final Function(String addressId) onSelect;
  final VoidCallback onAddNew;
  final VoidCallback onUseCurrentLocation;
  final Function(String pincode) onPincode;

  const AddressSelectDialog({
    super.key,
    required this.addresses,
    required this.onSelect,
    required this.onAddNew,
    required this.onUseCurrentLocation,
    required this.onPincode,
  });

  @override
  Widget build(BuildContext context) {
    TextEditingController pincodeController = TextEditingController();
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Select Delivery Address', style: Theme.of(context).textTheme.titleLarge),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (addresses.isNotEmpty)
              DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Saved Addresses'),
                items: addresses.map<DropdownMenuItem<String>>((address) {
                  return DropdownMenuItem<String>(
                    value: address['id'].toString(),
                    child: Text(address['address_line1'] + ', ' + address['city']),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) onSelect(value);
                },
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: pincodeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Enter Pincode',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    onPincode(pincodeController.text);
                  },
                )
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.my_location),
              label: const Text('Use Current Location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                textStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
              ),
              onPressed: onUseCurrentLocation,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add New Address'),
              onPressed: onAddNew,
            ),
          ],
        ),
      ),
    );
  }
}
