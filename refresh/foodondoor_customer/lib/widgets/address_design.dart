import 'package:flutter/material.dart';
import 'package:foodondoor_customer/models/address.dart';

class AddressDesign extends StatelessWidget {
  final Address? model;
  final int? selectedAddressId;
  final Function(int)? onSelect;

  AddressDesign({
    this.model,
    this.selectedAddressId,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (onSelect != null && model?.id != null) {
          onSelect!(model!.id!);
        }
      },
      child: Card(
        color: Colors.cyan.withOpacity(0.4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Row(
                children: [
                  Radio<int>(
                    groupValue: selectedAddressId,
                    value: model!.id!,
                    activeColor: Colors.amber,
                    onChanged: (value) {
                      if (onSelect != null && value != null) {
                        onSelect!(value);
                      }
                    },
                  ),
                  const SizedBox(
                    width: 10.0,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          model?.displayAddress ?? 'No Address Details',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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
}
