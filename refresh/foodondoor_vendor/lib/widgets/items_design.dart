import 'package:flutter/material.dart';
import 'package:foodondoor_vendor/mainScreens/item_detail_screen.dart';
import 'package:foodondoor_vendor/mainScreens/itemsScreen.dart';
import 'package:foodondoor_vendor/model/menus.dart';

class ItemDesignWidget extends StatefulWidget {
  final Map<String, dynamic>? itemData;
  final VoidCallback? onTap;

  const ItemDesignWidget({super.key, this.itemData, this.onTap});

  @override
  State<ItemDesignWidget> createState() => _ItemDesignWidgetState();
}

class _ItemDesignWidgetState extends State<ItemDesignWidget> {
  @override
  Widget build(BuildContext context) {
    final String title = widget.itemData?['name'] ?? 'No Title';
    final String thumbnailUrl = widget.itemData?['thumbnail_url'] ?? 
                               widget.itemData?['image_url'] ?? '';
    final String shortInfo = widget.itemData?['description'] ?? '';

    if (widget.itemData == null) {
      return const Card(
        child: ListTile(
          title: Text("Error: Item data missing"),
          leading: Icon(Icons.error, color: Colors.red),
        ),
      );
    }

    return InkWell(
      onTap: widget.onTap ?? () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => ItemDetailsScreen(itemData: widget.itemData)));
      },
      splashColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          child: Card(
            elevation: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (thumbnailUrl.isNotEmpty)
                  ClipRRect(
                     borderRadius: const BorderRadius.vertical(top: Radius.circular(4.0)),
                     child: Image.network(
                        thumbnailUrl,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                           return Container(
                              height: 180,
                              color: Theme.of(context).colorScheme.surfaceVariant,
                              child: Center(child: Icon(Icons.broken_image, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 40)),
                           );
                        },
                         loadingBuilder: (context, child, loadingProgress) {
                           if (loadingProgress == null) return child;
                           return Container(
                              height: 180,
                              color: Theme.of(context).colorScheme.surfaceVariant,
                              child: Center(child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                  : null,
                                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                              )),
                           );
                         },
                     ),
                  ),
                Padding(
                   padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                   child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                           color: Theme.of(context).colorScheme.primary,
                           fontFamily: "Train",
                           fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                   ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Text(
                    shortInfo,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
