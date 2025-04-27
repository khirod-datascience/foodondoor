import "package:flutter/material.dart";
import "package:fluttertoast/fluttertoast.dart";
import "package:number_inc_dec/number_inc_dec.dart";
import "../models/item.dart";
import "../widgets/app_bar.dart";
import "../widgets/progress_bar.dart";
import "../services/api_service.dart";
import "../assistant_methods/assistant_methods.dart";

class ItemDetailsScreen extends StatefulWidget {
  final String itemId;
  const ItemDetailsScreen({super.key, required this.itemId});

  @override
  State<ItemDetailsScreen> createState() => _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends State<ItemDetailsScreen> {
  TextEditingController counterTextEditingController = TextEditingController();
  Item? _item;
  bool _isLoading = true;
  String? _error;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    counterTextEditingController.text = "1";
    _fetchItemDetails();
  }

  Future<void> _fetchItemDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final endpoint = '/api/items/${widget.itemId}/';
      final response = await _apiService.get(endpoint);

      if (response['success'] == true && response is Map<String, dynamic>) {
        setState(() {
          _item = Item.fromJson(response);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response['error']?.toString() ?? 'Failed to load item details for ${widget.itemId}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "An error occurred: ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: circularProgress());
    }
    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }
    if (_item == null) {
      return const Center(child: Text('Item not found.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _item!.thumbnailUrl != null
          ? Image.network(
              _item!.thumbnailUrl!,
              width: MediaQuery.of(context).size.width,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => 
                Container(height: 220, width: MediaQuery.of(context).size.width, color: Colors.grey[200], child: Icon(Icons.broken_image, color: Colors.grey[400])),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 220,
                  width: MediaQuery.of(context).size.width,
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
          : Container(height: 220, width: MediaQuery.of(context).size.width, color: Colors.grey[200], child: Icon(Icons.no_food, color: Colors.grey[400], size: 100)),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: NumberInputPrefabbed.roundedButtons(
            controller: counterTextEditingController,
            incDecBgColor: Colors.pinkAccent,
            min: 1,
            max: 9,
            initialValue: 1,
            buttonArrangement: ButtonArrangement.incRightDecLeft,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            _item!.title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            _item!.longDescription ?? 'No description available.',
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
            _item!.price != null ? "₹ ${_item!.price}" : "Price N/A",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 26,
            ),
          ),
        ),
        const SizedBox(
          height: 10,
        ),
        Center(
          child: InkWell(
            onTap: () {
              int itemCounter = int.parse(counterTextEditingController.text);
              addItemToCartAPI(widget.itemId, itemCounter, context);
            },
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.redAccent, Colors.pinkAccent],
                  begin: FractionalOffset(0.0, 0.0),
                  end: FractionalOffset(1.0, 0.0),
                  stops: [0.0, 1.0],
                  tileMode: TileMode.clamp,
                ),
              ),
              height: 50,
              width: MediaQuery.of(context).size.width - 13,
              child: const Center(
                child: Text(
                  "Add to Cart",
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
            ),
          ),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Item Details', style: Theme.of(context).appBarTheme.titleTextStyle),
        centerTitle: true,
        elevation: 0,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _buildBody(),
    );
  }
}
