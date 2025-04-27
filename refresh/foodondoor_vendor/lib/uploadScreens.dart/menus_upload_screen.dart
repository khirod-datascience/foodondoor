import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../global/global.dart';
import '../mainScreens/home_screen.dart';
import '../widgets/error_Dialog.dart';
import '../widgets/loading_dialog.dart';
import '../widgets/progress_bar.dart';
import '../api/api_service.dart';

class MenusUploadScreen extends StatefulWidget {
  const MenusUploadScreen({super.key});

  @override
  State<MenusUploadScreen> createState() => _MenusUploadScreenState();
}

class _MenusUploadScreenState extends State<MenusUploadScreen> {
  XFile? imageXFile;
  final ImagePicker _picker = ImagePicker();
  TextEditingController shortInfoController = TextEditingController();
  TextEditingController titleController = TextEditingController();
  bool uploading = false;

  final ApiService _apiService = ApiService();

  defaultScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Add New Menu",
          style: TextStyle(fontSize: 30, fontFamily: "Lobster"),
        ),
        automaticallyImplyLeading: true,
        leading: IconButton(
            onPressed: () {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
            },
            icon: const Icon(
              Icons.arrow_back,
            )),
      ),
      body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shop_two,
                color: Theme.of(context).colorScheme.primary,
                size: 200,
              ),
              const SizedBox(height: 70,),
              ElevatedButton(
                onPressed: () {
                  tekeImage(context);
                },
                child: const Text(
                  'Add New Menu',
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
              "Menu Image",
              style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold),
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
                  style: TextStyle(color: Colors.red.shade700),
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
      imageXFile;
    });
  }

  pickImageFromGalary() async {
    Navigator.pop(context);
    imageXFile = await _picker.pickImage(
        source: ImageSource.gallery, maxHeight: 720, maxWidth: 1280);
    setState(() {
      imageXFile;
    });
  }

  menusUploadFormScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Uploading New Menu",
        ),
        automaticallyImplyLeading: true,
        leading: IconButton(
          onPressed: () {
            clearMenuUploaddForm();
          },
          icon: const Icon(
            Icons.arrow_back,
          ),
        ),
        actions: [
          TextButton(
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
            onPressed: uploading ? null : validateUploadForm,
          ),
        ],
      ),
      body: ListView(
        children: [
          uploading ? linearProgress() : const SizedBox.shrink(),
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
          Divider(color: Theme.of(context).colorScheme.primary.withOpacity(0.5), thickness: 1),
          ListTile(
            leading: Icon(
              Icons.title,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: SizedBox(
              width: 250,
              child: TextField(
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                controller: titleController,
                decoration: InputDecoration(
                    hintText: "menu title",
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    border: InputBorder.none),
              ),
            ),
          ),
          Divider(color: Theme.of(context).colorScheme.primary.withOpacity(0.5), thickness: 1),
          ListTile(
            leading: Icon(
              Icons.description,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: SizedBox(
              width: 250,
              child: TextField(
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                controller: shortInfoController,
                decoration: InputDecoration(
                    hintText: "menu description",
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

  clearMenuUploaddForm() {
    setState(() {
      shortInfoController.clear();
      titleController.clear();
      imageXFile = null;
    });
  }

  validateUploadForm() async {
    if (imageXFile == null) {
      showDialog(
          context: context,
          builder: (c) => const ErrorDialog(message: "Please pick an image for Menu.")
      );
      return;
    }

    if (shortInfoController.text.isEmpty || titleController.text.isEmpty) {
      showDialog(
          context: context,
          builder: (c) => const ErrorDialog(message: "Please write title and info for menu.")
      );
      return;
    }

    setState(() { uploading = true; });

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const LoadingDialog(message: "Uploading Menu...")
    );

    String? imagePath;
    String? errorMessage;

    try {
      final imageUploadResponse = await _apiService.uploadImage(File(imageXFile!.path));

      if (imageUploadResponse.containsKey('error') || !imageUploadResponse.containsKey('image_path')) {
        errorMessage = "Image upload failed: ${imageUploadResponse['error'] ?? 'Unknown error'}";
      } else {
        imagePath = imageUploadResponse['image_path'];
        debugPrint("Image uploaded successfully, path: $imagePath");
      }

      if (imagePath != null) {
        Map<String, dynamic> menuData = {
          "name": titleController.text.trim(),
          "description": shortInfoController.text.trim(),
          "image_path": imagePath,
          "price": 0,
          "status": "available"
        };

        final createMenuResponse = await _apiService.createMenu(menuData);

        if (createMenuResponse.containsKey('error')) {
          errorMessage = "Menu creation failed: ${createMenuResponse['error']}";
        } else {
          debugPrint("Menu created successfully: ${createMenuResponse}");
        }
      }
    } catch (e) {
      errorMessage = "An unexpected error occurred: $e";
      debugPrint(errorMessage);
    }

    if (mounted) {
       Navigator.pop(context);
    }

    if (errorMessage != null) {
      if (mounted) {
        showDialog(context: context, builder: (c) => ErrorDialog(message: errorMessage!));
      }
    } else {
      if (mounted) {
          clearMenuUploaddForm();
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Menu added successfully!'), backgroundColor: Colors.green)
          );
      }
    }

    if (mounted) {
       setState(() { uploading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return imageXFile == null ? defaultScreen() : menusUploadFormScreen();
  }
}
