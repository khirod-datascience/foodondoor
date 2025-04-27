import 'package:flutter/material.dart';

class SimpleAppBar extends StatelessWidget implements PreferredSizeWidget {
  String? title;

  final PreferredSizeWidget? bottom;

  SimpleAppBar({super.key, this.bottom, this.title});
  @override
  Size get preferredSize => bottom == null
      ? Size(56, AppBar().preferredSize.height)
      : Size(56, 80 + AppBar().preferredSize.height);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      // Remove flexibleSpace gradient to use AppBarTheme
      // flexibleSpace: Container(
      //   decoration: const BoxDecoration(
      //     gradient: LinearGradient(
      //       colors: [Colors.red, Colors.redAccent],
      //       begin: FractionalOffset(0.0, 0.0),
      //       end: FractionalOffset(1.0, 0.0),
      //       stops: [0.0, 1.0],
      //       tileMode: TileMode.clamp,
      //     ),
      //   ),
      // ),
      iconTheme: Theme.of(context).appBarTheme.iconTheme, // Ensure back button uses theme color
      title: Text(
        title ?? "", // Use null safety
        // Apply theme title style but keep Signatra font
        style: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
              fontFamily: "Signatra",
              fontSize: 35, // Slightly smaller size for Signatra
            ) ?? const TextStyle( // Fallback style
              fontFamily: "Signatra",
              fontSize: 35,
              color: Colors.white, // Default white if theme style is null
            ),
      ),
      // centerTitle: true, // Already centered by theme
      automaticallyImplyLeading: true,
      // Removed empty actions array
    );
  }
}
