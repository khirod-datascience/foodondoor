import 'package:flutter/material.dart';
import '../mainScreens/menus_screen.dart';
import '../models/vendor.dart';

class SellersDesignWidget extends StatefulWidget {
  final Vendor? model;
  final BuildContext? context;

  const SellersDesignWidget({super.key, this.model, this.context});

  @override
  State<SellersDesignWidget> createState() => _SellersDesignWidgetState();
}

class _SellersDesignWidgetState extends State<SellersDesignWidget> {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => MenusScreen(vendorId: widget.model!.id.toString())));
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
            widget.model?.sellerAvatarUrl != null 
              ? Image.network(
                  widget.model!.sellerAvatarUrl!,
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
              : Container(height: 220, color: Colors.grey[200], child: Icon(Icons.storefront, color: Colors.grey[400], size: 100)),

            const SizedBox(
              height: 10,
            ),
            Text(
              widget.model?.sellerName ?? 'Vendor Name N/A',
              style: const TextStyle(
                  color: Colors.pinkAccent, fontSize: 20, fontFamily: "Train"),
            ),
            Text(
              widget.model?.sellerEmail ?? 'Email N/A',
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
