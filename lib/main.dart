import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'add_food_screen.dart';
import 'auth_screen.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:vibration/vibration.dart';

import 'amplifyconfiguration.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureAmplify();
  runApp(MyApp());
}

Future<void> _configureAmplify() async {
  try {
    if (Amplify.isConfigured) return;

    await Amplify.addPlugins([
      AmplifyAuthCognito(),
      AmplifyAPI(),
      AmplifyStorageS3(),
    ]);

    await Amplify.configure(amplifyconfig);
  } catch (e) {
    print("❌ Error configuring Amplify: $e");
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Food Waste App',
      theme: ThemeData(primarySwatch: Colors.green),
      home: AuthScreen(),
      routes: {
        "/home": (context) => HomeScreen(),
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, String>> foodItems = [];

  Set<String> seenItems = {};
  int notificationCount = 0;

  @override
  void initState() {
    super.initState();
    fetchFood();
  }

  // ✅ NEW: GET S3 IMAGE URL
  Future<String> getImageUrl(String key) async {
    try {
      final result = await Amplify.Storage.getUrl(
        key: key,
      ).result;

      return result.url.toString();
    } catch (e) {
      print("Error getting image URL: $e");
      return "";
    }
  }

  void triggerNotificationAlert() async {
    if (Platform.isAndroid || Platform.isIOS) {
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: 500);
      }
    } else {
      SystemSound.play(SystemSoundType.alert);
    }
  }

  String getTimeLeft(String expiryTime) {
    DateTime expiry = DateTime.parse(expiryTime);
    Duration diff = expiry.difference(DateTime.now());

    if (diff.isNegative) return "Expired";
    return "${diff.inHours}h ${diff.inMinutes % 60}m left";
  }

  Future<void> openMap(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Map<String, List<Map<String, String>>> groupFoodItems() {
    Map<String, List<Map<String, String>>> grouped = {};
    for (var item in foodItems) {
      String key = item["title"] ?? "Unknown";
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(item);
    }
    return grouped;
  }

  Future<void> fetchFood() async {
    String query = '''
      query ListFoodItems {
        listFoodItems {
          items {
            id
            title
            hotel
            type
            expiryTime
            claimed
            image
            ngo
            hotelPhone
            hotelAddress
            hotelMapLink
          }
        }
      }
    ''';

    try {
      final response = await Amplify.API.query(
        request: GraphQLRequest<String>(document: query),
      ).response;

      if (response.data == null) return;

      final data = jsonDecode(response.data!);
      final List items = data["listFoodItems"]["items"];

      List<Map<String, String>> loadedFood = [];
      int newCount = 0;

      Set<String> tempSeen = Set.from(seenItems);

      for (var item in items) {
        if (item == null) continue;

        String expiryStr = item["expiryTime"]?.toString() ?? "";
        if (expiryStr.isEmpty) continue;

        DateTime expiry = DateTime.parse(expiryStr);
        if (expiry.isBefore(DateTime.now())) continue;

        String id = item["id"] ?? "";
        bool isClaimed = item["claimed"].toString() == "true";

        if (!tempSeen.contains(id) && !isClaimed) {
          newCount++;
        }

        loadedFood.add({
          "id": id,
          "title": item["title"] ?? "",
          "hotel": item["hotel"] ?? "",
          "type": item["type"] ?? "",
          "image": item["image"] ?? "",
          "expiryTime": expiryStr,
          "claimed": item["claimed"].toString(),
          "hotelPhone": item["hotelPhone"] ?? "",
          "hotelAddress": item["hotelAddress"] ?? "",
          "hotelMapLink": item["hotelMapLink"] ?? "",
        });
      }

      for (var item in loadedFood) {
        seenItems.add(item["id"]!);
      }

      setState(() {
        foodItems = loadedFood;
        notificationCount = newCount;
      });

      if (newCount > 0) {
        triggerNotificationAlert();
      }

    } catch (e) {
      print("Fetch error: $e");
    }
  }

  Future<void> addFood(Map<String, String> newFood) async {
    String mutation = '''
      mutation {
        createFoodItem(input: {
          title: "${newFood["title"]}",
          hotel: "${newFood["hotel"]}",
          type: "${newFood["type"]}",
          expiryTime: "${newFood["expiryTime"]}",
          image: "${newFood["image"]}",
          claimed: false,
          hotelPhone: "${newFood["hotelPhone"]}",
          hotelAddress: "${newFood["hotelAddress"]}",
          hotelMapLink: "${newFood["hotelMapLink"]}"
        }) { id }
      }
    ''';

    await Amplify.API.mutate(
      request: GraphQLRequest(document: mutation),
    ).response;

    fetchFood();
  }

  Future<void> claimFood(Map<String, String> item) async {
    await Amplify.API.mutate(
      request: GraphQLRequest(
        document:
            '''mutation { updateFoodItem(input:{id:"${item["id"]}", claimed:true}){id}}''',
      ),
    ).response;

    fetchFood();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "🎁 Food claimed successfully! Thank you for helping the community.",
        ),
      ),
    );

    if (item["hotelMapLink"] != null &&
        item["hotelMapLink"]!.isNotEmpty) {
      openMap(item["hotelMapLink"]!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupedItems = groupFoodItems();

    return Scaffold(
      appBar: AppBar(
        title: Text("Food Waste Management"),
        backgroundColor: Colors.green,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.notifications),
                onPressed: () {
                  setState(() {
                    notificationCount = 0;
                  });
                },
              ),
              if (notificationCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      notificationCount.toString(),
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await Amplify.Auth.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => AuthScreen()),
              );
            },
          )
        ],
      ),

      body: foodItems.isEmpty
          ? Center(child: Text("No food available"))
          : ListView(
              children: groupedItems.entries.map((entry) {
                return ExpansionTile(
                  title: Text(entry.key,
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  children: entry.value.map((item) {
                    return ListTile(
                      leading: item["image"] != null &&
                              item["image"]!.isNotEmpty
                          ? FutureBuilder<String>(
                              future: getImageUrl(item["image"]!),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData ||
                                    snapshot.data!.isEmpty) {
                                  return Icon(Icons.fastfood);
                                }

                                return Image.network(
                                  snapshot.data!,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                );
                              },
                            )
                          : Icon(Icons.fastfood),

                      title: Text(item["hotel"] ?? ""),

                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Type: ${item["type"]}"),
                          Text("⏳ ${getTimeLeft(item["expiryTime"]!)}"),
                        ],
                      ),

                      trailing: ElevatedButton(
                        onPressed: item["claimed"] == "true"
                            ? null
                            : () => claimFood(item),
                        child: Text(
                          item["claimed"] == "true"
                              ? "Claimed"
                              : "Claim",
                        ),
                      ),
                    );
                  }).toList(),
                );
              }).toList(),
            ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddFoodScreen(addFood: addFood),
            ),
          );
        },
        child: Icon(Icons.add),
      ),
    );
  }
}