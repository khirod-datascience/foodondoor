import 'package:flutter/material.dart';
import '../mainScreens/item_detail_screen.dart';
import '../models/item.dart';

class ItemsDesignWidget extends StatefulWidget {
  final Item? model;
  final BuildContext? context;

  const ItemsDesignWidget({super.key, this.model, this.context});

  @override
  State<ItemsDesignWidget> createState() => _ItemsDesignWidgetState();
}

class _ItemsDesignWidgetState extends State<ItemsDesignWidget> {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => ItemDetailsScreen(
                      itemId: widget.model!.itemId,
                    )));
      },
      splashColor: Colors.amber,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: SizedBox(
          height: 300,
          width: MediaQuery.of(context).size.width,
          child: Column(children: [
            Divider(
              height: 4,
              thickness: 3,
              color: Colors.grey[300],
            ),
            widget.model?.thumbnailUrl != null
              ? Image.network(
                  widget.model!.thumbnailUrl!,
                  height: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => 
                      Container(height: 220, color: Colors.grey[200], child: Icon(Icons.broken_image, color: Colors.grey[400])),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 220,
                      color: Colors.grey[200],
                      child: Center(
                        child: CircularProgressIndicator(
                           value: loadingProgress.expectedTotalBytes != null
                               ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                               : null,
                        ),
                      ),
                    );
                  },
                )
              : Container(height: 220, color: Colors.grey[200], child: Icon(Icons.no_food, color: Colors.grey[400], size: 100)),

            const SizedBox(
              height: 10,
            ),
            Text(
              widget.model?.title ?? 'Item Title N/A',
              style: const TextStyle(
                  color: Colors.pinkAccent, fontSize: 20, fontFamily: "Train"),
            ),
            Text(
              widget.model?.shortInfo ?? '',
              style: const TextStyle(
                  color: Colors.grey, fontSize: 12, fontFamily: "Train"),
            ),
            Divider(
              height: 4,
              thickness: 2,
              color: Colors.grey[300],
            )
          ]),
        ),
      ),
    );
  }
}
