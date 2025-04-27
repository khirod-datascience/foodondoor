import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../global/global.dart';
import '../api/api_service.dart';
import '../uploadScreens.dart/items_upload_screen.dart';
import '../widgets/items_design.dart';
import '../widgets/my_drower.dart';
import '../widgets/progress_bar.dart';
import '../widgets/text_widget_header.dart';
import 'item_detail_screen.dart';

class ItemsScreen extends StatefulWidget {
  final String? menuId;
  final String? menuName;

  const ItemsScreen({super.key, this.menuId, this.menuName});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> items = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    if (widget.menuId == null) {
      setState(() {
        isLoading = false;
        error = "Error: Menu ID is missing. Cannot load items.";
      });
      debugPrint(error);
    } else {
      _loadItems();
    }
  }

  Future<void> _loadItems() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    final response = await _apiService.getItemsForMenu(widget.menuId!);

    if (!mounted) return;

    setState(() {
      if (response.containsKey('error')) {
        error = response['error'];
        items = [];
        debugPrint("Error loading items for menu ${widget.menuId}: $error");
      } else if (response.containsKey('data') && response['data'] is List) {
        items = List<Map<String, dynamic>>.from(response['data']);
        error = null;
      } else {
        error = "Unexpected response format when fetching items.";
        items = [];
        debugPrint(error);
      }
      isLoading = false;
    });
  }

  Widget _buildBody() {
    if (isLoading) {
      return SliverFillRemaining(child: Center(child: circularProgress()));
    }
    if (error != null) {
      return SliverFillRemaining(child: Center(child: Text("Error: $error", style: const TextStyle(color: Colors.red))));
    }
    if (items.isEmpty) {
      return const SliverFillRemaining(child: Center(child: Text("No items found in this menu.")));
    }

    return SliverStaggeredGrid.countBuilder(
      crossAxisCount: 1,
      staggeredTileBuilder: (context) => const StaggeredTile.fit(1),
      itemBuilder: (context, index) {
        final itemData = items[index];
        return ItemDesignWidget(
          itemData: itemData,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (c) {
              return ItemDetailsScreen(itemData: itemData);
            }));
          },
        );
      },
      itemCount: items.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final menuTitle = widget.menuName ?? "Menu Items";

    return Scaffold(
      appBar: AppBar(
        title: Text(
          sharedPreferences!.getString("name") ?? "foodondoor",
          style: const TextStyle(fontSize: 30, fontFamily: "Lobster"),
        ),
        automaticallyImplyLeading: true,
        actions: [
          IconButton(
            onPressed: () async {
              final result = await Navigator.push(context, MaterialPageRoute(builder: (context) {
                 return ItemsUploadScreen(menuId: widget.menuId, menuName: widget.menuName);
              }));

              if (result == true && mounted) {
                _loadItems();
              }
            },
            icon: const Icon(Icons.library_add),
          )
        ],
      ),
      drawer: MyDrawer(),
      body: CustomScrollView(
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: TextWidgetHeader(title: "Items in '$menuTitle'"),
          ),
          _buildBody(),
        ],
      ),
    );
  }
}
