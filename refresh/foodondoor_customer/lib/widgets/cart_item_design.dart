import 'package:flutter/material.dart';
import '../models/cart_item.dart'; 
import '../models/food_item.dart'; 

class CartItemDesign extends StatelessWidget { 
  final CartItem model;
  final VoidCallback? onQuantityIncreased; 
  final VoidCallback? onQuantityDecreased; 
  final VoidCallback? onItemRemoved; 

  const CartItemDesign({
    super.key,
    required this.model,
    this.onQuantityIncreased,
    this.onQuantityDecreased,
    this.onItemRemoved,
  });

  @override
  Widget build(BuildContext context) {
    final FoodItem food = model.food; 
    final String thumbnailUrl = food.imageUrls.isNotEmpty ? food.imageUrls[0] : '';
    final String title = food.name;
    final double price = double.tryParse(food.price) ?? 0.0;
    final int quantity = model.quantity;
    final double lineTotal = price * quantity;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      child: Container(
        padding: const EdgeInsets.all(10.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10.0),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 2), 
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center, 
          children: [
            thumbnailUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.network(
                      thumbnailUrl,
                      width: 70, 
                      height: 70,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(width: 70, height: 70, color: Colors.grey[200], child: Icon(Icons.broken_image, color: Colors.grey[400], size: 30)),
                      loadingBuilder: (context, child, loadingProgress) {
                         if (loadingProgress == null) return child;
                         return Container(
                           width: 70,
                           height: 70,
                           color: Colors.grey[200],
                           child: Center(child: CircularProgressIndicator(strokeWidth: 2.0)),
                         );
                       },
                    ),
                  )
                : Container(
                    width: 70, height: 70, 
                    decoration: BoxDecoration(
                       color: Colors.grey[200],
                       borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Icon(Icons.fastfood_outlined, color: Colors.grey[400], size: 35),
                  ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 15, 
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "₹${price.toStringAsFixed(2)}", 
                    style:
                        TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.normal),
                  ),
                  const SizedBox(height: 8),
                   Row(
                    children: [
                      _buildQuantityButton(Icons.remove, onQuantityDecreased),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text(
                          quantity.toString(),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      _buildQuantityButton(Icons.add, onQuantityIncreased),
                    ],
                  )
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, 
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                 if (onItemRemoved != null)
                   IconButton(
                    icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                    padding: EdgeInsets.zero, 
                    constraints: const BoxConstraints(), 
                    onPressed: onItemRemoved,
                    tooltip: 'Remove Item',
                  ),
                 const Spacer(), 
                 Text(
                    "₹${lineTotal.toStringAsFixed(2)}",
                    style: const TextStyle(fontSize: 16, color: Colors.deepOrange, fontWeight: FontWeight.bold),
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityButton(IconData icon, VoidCallback? onPressed) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(4.0),
        decoration: BoxDecoration(
          color: onPressed != null ? Colors.grey[200] : Colors.grey[300], 
          borderRadius: BorderRadius.circular(4.0),
          border: Border.all(color: Colors.grey[300]!)
        ),
        child: Icon(
          icon,
          size: 18.0,
          color: onPressed != null ? Colors.black87 : Colors.grey,
        ),
      ),
    );
  }
}
