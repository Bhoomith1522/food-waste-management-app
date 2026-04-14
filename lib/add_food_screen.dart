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

class _AddFoodScreenState extends State<AddFoodScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController hotelController = TextEditingController();
  final TextEditingController typeController = TextEditingController();

  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController mapLinkController = TextEditingController();

  File? _image;
  bool isLoading = false;

  // ✅ NEW: EXPIRY VARIABLE
  DateTime? selectedExpiry;

  // 🤖 BOT STATE
  bool showBot = false;
  int botStep = 0;

  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  List<String> botMessages = [
    "👋 Hi! I’ll guide you to add food.",
    "🍱 Enter food title (e.g. Rice, Curry)",
    "🏨 Enter hotel name",
    "🥗 Mention food type (Veg/Non-Veg)",
    "📞 Add hotel phone number",
    "📍 Add address & map link",
    "📸 Upload food image",
    "⏰ Select expiry time",
    "✅ Finally click Submit!"
  ];

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );

    _scaleAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void nextBotStep() {
    if (botStep < botMessages.length - 1) {
      setState(() => botStep++);
    } else {
      _controller.reverse();
      Future.delayed(Duration(milliseconds: 300), () {
        setState(() => showBot = false);
      });
    }
  }

  // 🔥 CENTER POPUP
  void showAppreciationPopup(String message) {
    final overlay = Overlay.of(context);

    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.4)),
          ),
          Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.6,
                padding: EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.celebration,
                        size: 50, color: Colors.green),
                    SizedBox(height: 10),
                    Text("Great Job!",
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    Text(message, textAlign: TextAlign.center),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        overlayEntry.remove();
                      },
                      child: Text("OK"),
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    overlay.insert(overlayEntry);
  }

  // 📸 PICK IMAGE
  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        _image = File(picked.path);
      });
    }
  }

  // ☁️ UPLOAD IMAGE
  Future<String> uploadImage(File file) async {
    final key = "images/${DateTime.now().millisecondsSinceEpoch}.jpg";

    await Amplify.Storage.uploadFile(
      localFile: AWSFile.fromPath(file.path),
      key: key,
    ).result;

    return key;
  }

  // ✅ PICK EXPIRY DATE + TIME
  Future<void> pickExpiryDateTime() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 7)),
    );

    if (pickedDate == null) return;

    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (pickedTime == null) return;

    setState(() {
      selectedExpiry = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  bool validateInputs() {
    if (titleController.text.isEmpty ||
        hotelController.text.isEmpty ||
        typeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please fill all required fields")),
      );
      return false;
    }

    if (selectedExpiry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select expiry date & time")),
      );
      return false;
    }

    return true;
  }

  void submitFood() async {
    if (!validateInputs()) return;

    setState(() => isLoading = true);

    String imageKey = "";

    if (_image != null) {
      imageKey = await uploadImage(_image!);
    }

    widget.addFood({
      "title": titleController.text,
      "hotel": hotelController.text,
      "type": typeController.text,
      "expiryTime": selectedExpiry!.toUtc().toIso8601String(),
      "image": imageKey,
      "hotelPhone": phoneController.text,
      "hotelAddress": addressController.text,
      "hotelMapLink": mapLinkController.text,
    });

    setState(() => isLoading = false);

    showAppreciationPopup(
      "🎉 Thank you for contributing! Your kindness helps reduce food waste.",
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Add Food"),
        backgroundColor: Colors.green,
      ),
      body: Stack(
        children: [
          Padding(
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

                  SizedBox(height: 15),

                  // ✅ EXPIRY PICKER UI
                  ElevatedButton(
                    onPressed: pickExpiryDateTime,
                    child: Text("Select Expiry Date & Time"),
                  ),

                  SizedBox(height: 10),

                  Text(
                    selectedExpiry == null
                        ? "No expiry selected"
                        : "Expiry: ${selectedExpiry.toString()}",
                    style: TextStyle(color: Colors.grey),
                  ),

                  SizedBox(height: 15),

                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(labelText: "Hotel Phone"),
                  ),
                  TextField(
                    controller: addressController,
                    decoration: InputDecoration(labelText: "Hotel Address"),
                  ),
                  TextField(
                    controller: mapLinkController,
                    decoration:
                        InputDecoration(labelText: "Google Maps Link"),
                  ),

                  SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: pickImage,
                    child: Text("Pick Image"),
                  ),

                  if (_image != null)
                    Image.file(_image!, height: 120),

                  SizedBox(height: 20),

                  isLoading
                      ? CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: submitFood,
                          child: Text("Submit"),
                        ),
                ],
              ),
            ),
          ),

          // 🤖 CHATBOT
          if (showBot)
            Center(
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: FadeTransition(
                  opacity: _scaleAnimation,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.8,
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.smart_toy,
                            size: 50, color: Colors.green),
                        Text(botMessages[botStep],
                            textAlign: TextAlign.center),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                                onPressed: () {
                                  _controller.reverse();
                                  setState(() => showBot = false);
                                },
                                child: Text("Close")),
                            ElevatedButton(
                                onPressed: nextBotStep,
                                child: Text("Next")),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),

          Positioned(
            bottom: 30,
            right: 20,
            child: GestureDetector(
              onTap: () {
                setState(() => showBot = !showBot);
                showBot ? _controller.forward() : _controller.reverse();
              },
              child: CircleAvatar(
                radius: 30,
                backgroundColor: Colors.green,
                child: Icon(Icons.smart_toy, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}