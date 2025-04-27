import "package:flutter/material.dart";
import "package:fluttertoast/fluttertoast.dart";
import "../global/global.dart";
import "../splashScreen/splash_screen.dart";
import "../widgets/simple_Appbar.dart";
import "../api/api_service.dart";
import "../widgets/loading_dialog.dart";
import "../widgets/error_Dialog.dart";

class ItemDetailsScreen extends StatefulWidget {
  final Map<String, dynamic>? itemData;
  const ItemDetailsScreen({super.key, this.itemData});

  @override
  State<ItemDetailsScreen> createState() => _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends State<ItemDetailsScreen> {
  final ApiService _apiService = ApiService();
  bool _isDeleting = false;

  Future<void> _deleteItem(String itemId) async {
    if (_isDeleting) return;

    setState(() { _isDeleting = true; });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const LoadingDialog(message: "Deleting item..."),
    );

    String? errorMessage;
    try {
      final response = await _apiService.deleteItem(itemId);

      if (!mounted) return;
      Navigator.pop(context);

      if (response.containsKey('error')) {
        errorMessage = "Failed to delete item: ${response['error']}";
      } else {
        Fluttertoast.showToast(msg: "Item deleted successfully");
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      errorMessage = "An unexpected error occurred: $e";
      debugPrint(errorMessage);
    }

    if (errorMessage != null && mounted) {
      showDialog(context: context, builder: (c) => ErrorDialog(message: errorMessage!));
    }

    if (mounted) {
      setState(() { _isDeleting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemData == null) {
      return Scaffold(
        appBar: SimpleAppBar(title: sharedPreferences!.getString("name") ?? "Error"),
        body: const Center(child: Text("Error: Item data not found.")),
      );
    }

    final String itemId = widget.itemData!['id']?.toString() ?? '';
    final String thumbnailUrl = widget.itemData!['thumbnail_url'] ??
                                 widget.itemData!['image_url'] ??
                                 '';
    final String title = widget.itemData!['name'] ?? 'No Title';
    final String description = widget.itemData!['description'] ?? 'No Description';
    final String price = widget.itemData!['price']?.toString() ?? '0.00';

    return Scaffold(
      appBar: SimpleAppBar(
        title: sharedPreferences!.getString("name") ?? "Vendor",
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (thumbnailUrl.isNotEmpty)
              Image.network(
                 thumbnailUrl,
                 errorBuilder: (context, error, stackTrace) {
                    debugPrint("Error loading item image: $error");
                    return Container(
                       height: 200,
                       color: Colors.grey[300],
                       child: const Center(child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey)),
                    );
                 },
                 loadingBuilder: (context, child, loadingProgress) {
                   if (loadingProgress == null) return child;
                   return Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: Center(
                         child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null,
                         ),
                      ),
                   );
                 },
              ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                description,
                textAlign: TextAlign.justify,
                style: const TextStyle(
                  fontWeight: FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "₹ $price",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 26,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
                child: InkWell(
                  onTap: () {
                    if (itemId.isNotEmpty) {
                       _deleteItem(itemId);
                    } else {
                       Fluttertoast.showToast(msg: "Error: Cannot delete item. ID is missing.");
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: const LinearGradient(
                        colors: [Colors.pinkAccent, Colors.redAccent],
                        begin: FractionalOffset(0.0, 0.0),
                        end: FractionalOffset(1.0, 0.0),
                        stops: [0.0, 1.0],
                        tileMode: TileMode.clamp,
                      ),
                    ),
                    height: 50,
                    width: MediaQuery.of(context).size.width - 13,
                    child: Center(
                      child: _isDeleting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "Delete this item",
                              style: TextStyle(color: Colors.white, fontSize: 15),
                            ),
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
