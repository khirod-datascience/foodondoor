import 'package:flutter/material.dart';
import '../models/category.dart';
import '../widgets/progress_bar.dart';

import 'HomeLargeItems.dart';
import 'HomePageMediumItems.dart';

class Home extends StatefulWidget {
  final List<dynamic> categories;

  const Home({super.key, required this.categories});

  @override
  State<Home> createState() => _DiningPagePageState();
}

class _DiningPagePageState extends State<Home> {
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            height: 10,
          ),
          const SizedBox(
            height: 250,
            width: double.infinity,
            child: HomeLargeItems(),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(15.0, 30.0, 15.0, 10.0),
            child: Text(
              'EXPLORE',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 126, 126, 126)),
            ),
          ),
          const SizedBox(
            height: 180,
            width: double.infinity,
            child: HomeMediumItems(),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(15.0, 30.0, 15.0, 10.0),
            child: Text(
              'CATEGORIES',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 126, 126, 126)),
            ),
          ),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.categories.length,
              itemBuilder: (context, index) {
                final category = widget.categories[index];
                final categoryModel = CategoryModel.fromJson(category as Map<String, dynamic>);

                return Padding(
                  padding: const EdgeInsets.only(left: 15.0, right: 5.0),
                  child: InkWell(
                    onTap: () {
                      print('Tapped category: ${categoryModel.name}');
                    },
                    child: SizedBox(
                      width: 100,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(
                            child: Card(
                              clipBehavior: Clip.antiAlias,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: categoryModel.image != null && categoryModel.image!.isNotEmpty
                                ? Image.network(
                                    categoryModel.image!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(child: circularProgress());
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Center(
                                        child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
                                      );
                                    },
                                  )
                                : const Center(
                                    child: Icon(Icons.category, color: Colors.grey, size: 40),
                                  ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            categoryModel.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.textTheme.bodyLarge?.color ?? Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(15.0, 30.0, 15.0, 10.0),
            child: Text(
              'IN THE SPOTLIGHT',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 126, 126, 126)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(15.0, 30.0, 15.0, 10.0),
            child: Text(
              'OUR RESTAURANTS',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 126, 126, 126)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(15.0, 8.0, 15.0, 20.0),
            child: Text(
              'FEATURES',
              style: TextStyle(
                  fontSize: 15, color: Color.fromARGB(255, 126, 126, 126)),
            ),
          ),
        ],
      ),
    );
  }
}
