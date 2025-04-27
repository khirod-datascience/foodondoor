import 'package:flutter/material.dart';
import '../mainScreens/items_screen.dart';
import '../models/food_item.dart';

class MenusDesignWidget extends StatefulWidget {
  final FoodItem? model;
  final BuildContext? context;
  final String vendorId;

  const MenusDesignWidget({super.key, this.model, this.context, required this.vendorId});

  @override
  State<MenusDesignWidget> createState() => _MenusDesignWidgetState();
}

class _MenusDesignWidgetState extends State<MenusDesignWidget> {
  @override
  Widget build(BuildContext context) {
    if (widget.model == null) {
      return const SizedBox.shrink();
    }

    final String name = widget.model!.name;
    final String? description = widget.model!.description;
    final String price = widget.model!.price;
    final List<String> imageUrls = widget.model!.imageUrls;
    final String? firstImageUrl = imageUrls.isNotEmpty ? imageUrls[0] : null;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ItemsScreen(model: widget.model!, vendorId: widget.vendorId),
          ),
        );
      },
      splashColor: Colors.redAccent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 5.0),
        child: Card(
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: firstImageUrl != null
                    ? Image.network(
                        firstImageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(color: Colors.grey[200], child: Icon(Icons.fastfood, color: Colors.grey[400])),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Colors.grey[200],
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                    : null,
                                strokeWidth: 2,
                              ),
                            ),
                          );
                        },
                      )
                    : Container(color: Colors.grey[200], child: Icon(Icons.fastfood, color: Colors.grey[400], size: 50)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (description != null && description.isNotEmpty)
                        Text(
                          description,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 8),
                      Text(
                        "₹$price",
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
