import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:amplify_flutter/amplify_flutter.dart';

class AddFoodScreen extends StatefulWidget {
  final Function(Map<String, String>) addFood;

  AddFoodScreen({required this.addFood});

  @override
  _AddFoodScreenState createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends State<AddFoodScreen> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController hotelController = TextEditingController();
  final TextEditingController typeController = TextEditingController();

  File? _image;

  // 📸 PICK IMAGE
  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        _image = File(picked.path);
      });
    }
  }

  // ☁️ UPLOAD TO S3
Future<String> uploadImage(File file) async {
  try {
    final key = "images/${DateTime.now().millisecondsSinceEpoch}.jpg";

    final result = await Amplify.Storage.uploadFile(
      localFile: AWSFile.fromPath(file.path), // ✅ FIXED
      key: key,
    ).result;

    return key;
  } catch (e) {
    print("Upload error: $e");
    return "";
  }
}

  // ✅ SUBMIT FOOD
  void submitFood() async {
    String imageKey = "";

    if (_image != null) {
      imageKey = await uploadImage(_image!);
    }

    DateTime expiry = DateTime.now().add(Duration(hours: 2));

    widget.addFood({
      "title": titleController.text,
      "hotel": hotelController.text,
      "type": typeController.text,
      "expiryTime": expiry.toUtc().toIso8601String(),
      "image": imageKey,
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Add Food"),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(labelText: "Food Title"),
              ),
              TextField(
                controller: hotelController,
                decoration: InputDecoration(labelText: "Hotel Name"),
              ),
              TextField(
                controller: typeController,
                decoration: InputDecoration(labelText: "Veg / Non-Veg"),
              ),

              SizedBox(height: 20),

              ElevatedButton(
                onPressed: pickImage,
                child: Text("Pick Image"),
              ),

              if (_image != null)
                Padding(
                  padding: EdgeInsets.all(10),
                  child: Image.file(_image!, height: 120),
                ),

              SizedBox(height: 20),

              ElevatedButton(
                onPressed: submitFood,
                child: Text("Submit"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}