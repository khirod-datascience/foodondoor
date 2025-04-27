// ignore_for_file: non_constant_identifier_names

import 'dart:io';
import 'dart:convert';

// Remove Firebase imports
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_storage/firebase_storage.dart' as storageRef;

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import '../global/global.dart';
// Import correct home screen if needed for back navigation
// import '../mainScreens/home_screen.dart';
import '../mainScreens/itemsScreen.dart'; // For navigating back
// Remove old model import if not used
// import '../model/menus.dart';
import '../widgets/error_Dialog.dart';
import '../widgets/progress_bar.dart';
import '../widgets/loading_dialog.dart'; // Import loading dialog
import '../api/api_service.dart'; // Import ApiService

class ItemsUploadScreen extends StatefulWidget {
  // Pass menuId and menuName instead of Menus model
  final String? menuId;
  final String? menuName; // Optional: for display purposes

  const ItemsUploadScreen({super.key, this.menuId, this.menuName});

  @override
  State<ItemsUploadScreen> createState() => _ItemsUploadScreenState();
}

class _ItemsUploadScreenState extends State<ItemsUploadScreen> {
  XFile? imageXFile;
  final ImagePicker _picker = ImagePicker();
  TextEditingController titleController = TextEditingController();
  TextEditingController shortInfoController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  TextEditingController priceController = TextEditingController();
  bool uploading = false;

  // Inject ApiService
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    // Print the menu ID when the screen initializes
    print("--- ItemsUploadScreen Initialized ---");
    print("Received menuId: ${widget.menuId}");
    print("Received menuName: ${widget.menuName}"); // Optional: useful for context
    print("------------------------------------");
  }

  // Keep defaultScreen, takeImage, captureImageWithCamera, pickImageFromGalary
  // Adjust back navigation in defaultScreen if necessary
  defaultScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Add New Items",
          style: TextStyle(fontSize: 30, fontFamily: "Lobster"),
        ),
        automaticallyImplyLeading: true,
        leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(
              Icons.arrow_back,
            )),
      ),
      body: Center(
        child: Column(
           mainAxisAlignment: MainAxisAlignment.center, // Center content
          children: [
            Icon(
              Icons.fastfood, // Changed icon
              color: Theme.of(context).colorScheme.primary, // Use theme color
              size: 200,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                tekeImage(context);
              },
              child: const Text(
                'Add Item Image', // Changed text
              ),
            ),
          ],
        ),
      ),
    );
  }

  tekeImage(mContext) {
    return showDialog(
        context: mContext,
        builder: (context) {
          final colorScheme = Theme.of(context).colorScheme;
          return SimpleDialog(
            title: Text(
              "Item Image", // Changed title
              style:
                  TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold), // Theme primary
            ),
            children: [
              SimpleDialogOption(
                onPressed: captureImageWithCamera,
                child: const Text(
                  "Capture with Phone Camera",
                ),
              ),
              SimpleDialogOption(
                onPressed: pickImageFromGalary,
                child: const Text(
                  "Select from Galary",
                ),
              ),
              SimpleDialogOption(
                child: Text(
                  "Cancel",
                  style: TextStyle(color: Colors.red.shade700), // Keep cancel red
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          );
        });
  }

  captureImageWithCamera() async {
    Navigator.pop(context);
    imageXFile = await _picker.pickImage(
        source: ImageSource.camera, maxHeight: 720, maxWidth: 1280);
    setState(() {
      imageXFile; // Update UI to show the form
    });
  }

  pickImageFromGalary() async {
    Navigator.pop(context);
    imageXFile = await _picker.pickImage(
        source: ImageSource.gallery, maxHeight: 720, maxWidth: 1280);
    setState(() {
      imageXFile; // Update UI to show the form
    });
  }

  // Refactored form screen
  ItemsUploadFormScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Adding New Item", // Changed title
        ),
        automaticallyImplyLeading: true,
        leading: IconButton(
          onPressed: () {
            clearItemUploadForm();
          },
          icon: const Icon(
            Icons.arrow_back,
          ),
        ),
        actions: [
          TextButton(
            onPressed: uploading ? null : () => validateItemUploadForm(),
            child: Text(
              "Add",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                fontFamily: "Varela",
                letterSpacing: 3,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        children: [
          uploading ? linearProgress() : const SizedBox.shrink(), // Use SizedBox
          // Image preview
          SizedBox(
            height: 230,
            width: MediaQuery.of(context).size.width * 0.8,
            child: Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                        image: FileImage(
                          File(imageXFile!.path),
                        ),
                        fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
          ),
          Divider(color: Theme.of(context).colorScheme.primary.withOpacity(0.5), thickness: 1), // Theme color divider
          // Item Name (Title)
          ListTile(
            leading: Icon(Icons.title, color: Theme.of(context).colorScheme.primary), // Theme color icon
            title: SizedBox(
              width: 250,
              child: TextField(
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color), // Theme text color
                controller: titleController,
                decoration: InputDecoration(
                    hintText: "Item Name",
                    hintStyle: TextStyle(color: Colors.grey.shade600), // Keep hint grey
                    border: InputBorder.none),
              ),
            ),
          ),
          Divider(color: Theme.of(context).colorScheme.primary.withOpacity(0.5), thickness: 1),
          // Item Short Info
          ListTile(
            leading: Icon(Icons.perm_device_information, color: Theme.of(context).colorScheme.primary),
            title: SizedBox(
              width: 250,
              child: TextField(
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                controller: shortInfoController,
                decoration: InputDecoration(
                    hintText: "Short Info (e.g., ingredients, size)",
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    border: InputBorder.none),
              ),
            ),
          ),
          Divider(color: Theme.of(context).colorScheme.primary.withOpacity(0.5), thickness: 1),
           // Item Long Description
          ListTile(
            leading: Icon(Icons.description, color: Theme.of(context).colorScheme.primary),
            title: SizedBox(
              width: 250,
              child: TextField(
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                controller: descriptionController,
                decoration: InputDecoration(
                    hintText: "Full Description",
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    border: InputBorder.none),
              ),
            ),
          ),
          Divider(color: Theme.of(context).colorScheme.primary.withOpacity(0.5), thickness: 1),
          // Item Price
          ListTile(
            leading: Icon(Icons.currency_rupee_sharp, color: Theme.of(context).colorScheme.primary),
            title: SizedBox(
              width: 250,
              child: TextField(
                keyboardType: TextInputType.number,
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                controller: priceController,
                decoration: InputDecoration(
                    hintText: "Price",
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    border: InputBorder.none),
              ),
            ),
          ),
          Divider(color: Theme.of(context).colorScheme.primary.withOpacity(0.5), thickness: 1),
        ],
      ),
    );
  }

  // Changed name
  clearItemUploadForm() {
    setState(() {
      shortInfoController.clear();
      titleController.clear();
      priceController.clear();
      descriptionController.clear();
      imageXFile = null; // Go back to the initial screen
    });
  }

  // Refactored validation and upload function
  validateItemUploadForm() async {
    print("--- Starting Item Upload Validation ---"); // DEBUG
    print("Current menuId: ${widget.menuId}"); // DEBUG
    if (imageXFile == null) {
      showDialog(
          context: context,
          builder: (c) {
            return ErrorDialog(message: "Please pick an image for the Item.");
          });
    } else {
      if (titleController.text.isNotEmpty &&
          descriptionController.text.isNotEmpty && // Added description check
          priceController.text.isNotEmpty) {
        // Check if menuId is valid
        if (widget.menuId == null || widget.menuId!.isEmpty) {
          print("ERROR: menuId is null or empty!"); // DEBUG
           showDialog(
              context: context,
              builder: (c) {
                return ErrorDialog(message: "Internal error: Menu ID is missing.");
              });
          return; // Stop execution
        }

        setState(() {
          uploading = true;
        });

        // Show loading dialog
        showDialog(
            context: context,
            barrierDismissible: false, // Prevent closing by tapping outside
            builder: (c) => LoadingDialog(message: "Uploading item..."));

        String? uploadedImagePath;
        try {
          // 1. Upload image first (if required by backend)
          print("Attempting to upload image..."); // DEBUG
          final imageResponse = await _apiService.uploadImage(File(imageXFile!.path));
          uploadedImagePath = imageResponse['image_path']; // Adjust based on actual API response key
          print("Image uploaded successfully, path: $uploadedImagePath"); // DEBUG

          if (uploadedImagePath == null || uploadedImagePath.isEmpty) {
             throw Exception("Image upload failed or returned empty path.");
          }

          // 2. Add item details using the returned image path
          print("Attempting to add item to menu ${widget.menuId}..."); // DEBUG
          // Create the item data map
          Map<String, dynamic> itemData = {
            "name": titleController.text.trim(),
            "description": descriptionController.text.trim(),
            "price": double.parse(priceController.text.trim()),
            "image_path": uploadedImagePath, // Backend expects the relative path
            "is_available": true, // Defaulting to true
          };

          print("Item Data Map: $itemData"); // DEBUG

          // Call with positional arguments
          final responseMap = await _apiService.addItemToMenu(
            widget.menuId!,
            itemData,
          );

          // Check response map for errors (optional, as _handleResponse might throw)
          if (responseMap.containsKey('error')) {
             throw Exception("API returned error: ${responseMap['error']}");
          }

           // Hide loading dialog on success
          Navigator.pop(context); // Close the loading dialog

          print("Item added successfully!"); // DEBUG
          Fluttertoast.showToast(msg: "Item Uploaded Successfully.");
          clearItemUploadForm(); // Clear form
          setState(() {
            uploading = false;
          });
          // Pop with a success indicator
          if (mounted) { // Check if the widget is still in the tree
            Navigator.pop(context, true); // Return true to signal success
          }

        } catch (e) {
           // Hide loading dialog on error
           Navigator.pop(context); // Close the loading dialog

          print("!!! ERROR during item upload: $e"); // DEBUG
          // // Print more details if it's an ApiServiceException (REMOVED)
          // if (e is ApiServiceException) {
          //   print("API Error Status Code: ${e.statusCode}"); // DEBUG
          //   print("API Error Response Body: ${e.responseBody}"); // DEBUG
          // }

          Fluttertoast.showToast(msg: "Error adding item: ${e.toString()}");
          setState(() {
            uploading = false;
          });
           showDialog(
              context: context,
              builder: (c) {
                 // Show specific API error or generic message
                 String errorMessage = "Item upload failed.";
                 // Attempt to extract error from exception message or response body if possible
                 // This part remains largely the same, trying to decode if 'e' holds the response
                 // Note: The actual exception 'e' might not directly contain statusCode/responseBody
                 // unless ApiService is modified to throw a custom exception with that data.
                 // For now, we rely on the exception's toString() or parsing it if it looks like JSON.

                 // Simplified check: Try to decode 'e.toString()' if it looks like a JSON error map
                 String errorString = e.toString();
                 dynamic errorJson;
                 try {
                   // A bit of a heuristic: check if it looks like a JSON map from _handleResponse
                   if (errorString.contains('"error"') || errorString.contains('"detail"') || errorString.contains('"menu"')) {
                      // Remove potential "Exception: " prefix
                      if (errorString.startsWith("Exception: ")) {
                          errorString = errorString.substring(11);
                      }
                      errorJson = jsonDecode(errorString);
                   }
                 } catch (_) {
                   // Ignore decoding errors
                 }

                 if (errorJson != null && errorJson is Map) {
                     if (errorJson.containsKey('detail')) {
                       errorMessage = errorJson['detail'];
                     } else if (errorJson.containsKey('menu') && errorJson['menu'] is List && errorJson['menu'].isNotEmpty) {
                       errorMessage = "Menu Error: ${errorJson['menu'][0]}";
                     } else if (errorJson.containsKey('error')) { // Check for generic 'error' key from ApiService
                       errorMessage = errorJson['error'];
                     } else {
                       errorMessage = errorJson.toString();
                     }
                 } else {
                   // Fallback to the original exception string if no JSON detected or parsed
                   errorMessage = e.toString();
                 }

                // // OLD LOGIC using ApiServiceException (REMOVED)
                // if (e is ApiServiceException && e.responseBody != null) {
                //    ...
                // }

                return ErrorDialog(message: errorMessage);
              });
        }
      } else {
        showDialog(
          context: context,
          builder: (c) => ErrorDialog(message: "Please fill in all fields."));
      }
    }
  }

  // REMOVE Firebase specific methods
  // saveInfo(String downloadUrl) { ... }
  // uploadImage(mImageFile) async { ... }

  @override
  Widget build(BuildContext context) {
    // Show form screen if image is picked, otherwise show default screen
    return imageXFile == null ? defaultScreen() : ItemsUploadFormScreen();
  }
}
