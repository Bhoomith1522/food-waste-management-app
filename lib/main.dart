import 'dart:convert';
import 'package:flutter/material.dart';
import 'add_food_screen.dart';
import 'auth_screen.dart';

// Amplify imports
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
    final authPlugin = AmplifyAuthCognito();
    final apiPlugin = AmplifyAPI();
    final storagePlugin = AmplifyStorageS3();

    await Amplify.addPlugins([
      authPlugin,
      apiPlugin,
      storagePlugin,
    ]);

    await Amplify.configure(amplifyconfig);

    print("✅ Amplify configured");
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

      // 🔥 START WITH AUTH
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
  Set<String> favorites = {};

  @override
  void initState() {
    super.initState();
    fetchFood();
  }

  // ⏳ EXPIRY TIMER
  String getTimeLeft(String expiryTime) {
    DateTime expiry = DateTime.parse(expiryTime);
    Duration diff = expiry.difference(DateTime.now());

    if (diff.isNegative) return "Expired";

    return "${diff.inHours}h ${diff.inMinutes % 60}m left";
  }

  // ❤️ FAVORITE TOGGLE
  void toggleFavorite(String id) {
    setState(() {
      if (favorites.contains(id)) {
        favorites.remove(id);
      } else {
        favorites.add(id);
      }
    });
  }

  // ✅ FETCH FOOD
  Future<void> fetchFood() async {
    String graphQLDocument = '''
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
          }
        }
      }
    ''';

    try {
      final request = GraphQLRequest<String>(document: graphQLDocument);
      final response = await Amplify.API.query(request: request).response;

      final data = jsonDecode(response.data!);
      final List items = data["listFoodItems"]["items"];

      List<Map<String, String>> loadedFood = [];

      for (var item in items) {
        if (item == null) continue;

        DateTime expiry = DateTime.parse(item["expiryTime"]);
        if (expiry.isBefore(DateTime.now())) continue;

        loadedFood.add({
          "id": item["id"] ?? "",
          "title": item["title"] ?? "",
          "hotel": item["hotel"] ?? "",
          "type": item["type"] ?? "",
          "image": item["image"] ?? "",
          "expiryTime": item["expiryTime"] ?? "",
          "claimed": item["claimed"].toString(),
        });
      }

      setState(() {
        foodItems = loadedFood;
      });
    } catch (e) {
      print("Error fetching food: $e");
    }
  }

  // ✅ ADD FOOD
  Future<void> addFood(Map<String, String> newFood) async {
    print("🔥 Sending food: $newFood");

    String graphQLDocument = '''
      mutation CreateFoodItem {
        createFoodItem(input: {
          title: "${newFood["title"]}",
          hotel: "${newFood["hotel"]}",
          type: "${newFood["type"]}",
          expiryTime: "${newFood["expiryTime"]}",
          image: "${newFood["image"]}",
          claimed: false
        }) {
          id
        }
      }
    ''';

    try {
      final request = GraphQLRequest<String>(document: graphQLDocument);
      await Amplify.API.mutate(request: request).response;

      fetchFood();
    } catch (e) {
      print("❌ Error adding food: $e");
    }
  }

  // ✅ CLAIM FOOD
  Future<void> claimFood(String id) async {
    String graphQLDocument = '''
      mutation UpdateFoodItem {
        updateFoodItem(input: {
          id: "$id",
          claimed: true
        }) {
          id
        }
      }
    ''';

    try {
      final request = GraphQLRequest<String>(document: graphQLDocument);
      await Amplify.API.mutate(request: request).response;
      fetchFood();
    } catch (e) {
      print("Error claiming food: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Food Waste Management"),
        centerTitle: true,
        backgroundColor: Colors.green,

        // 🔥 LOGOUT BUTTON (NEW)
        actions: [
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

      // 🔽 EVERYTHING BELOW UNTOUCHED
      body: foodItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fastfood, size: 80, color: Colors.grey),
                  SizedBox(height: 10),
                  Text(
                    "No food available",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: foodItems.length,
              itemBuilder: (context, index) {
                final item = foodItems[index];

                return Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  margin:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: item["image"]!.isNotEmpty
                              ? FutureBuilder(
                                  future: Amplify.Storage.getUrl(
                                    key: item["image"]!,
                                  ).result,
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                            ConnectionState.done &&
                                        snapshot.hasData) {
                                      return Image.network(
                                        snapshot.data!.url.toString(),
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                      );
                                    }
                                    return Container(
                                      width: 80,
                                      height: 80,
                                      color: Colors.grey[300],
                                      child: Icon(Icons.image),
                                    );
                                  },
                                )
                              : Container(
                                  width: 80,
                                  height: 80,
                                  color: Colors.grey[300],
                                  child: Icon(Icons.fastfood),
                                ),
                        ),

                        SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                item["title"] ?? "",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                item["hotel"] ?? "",
                                style:
                                    TextStyle(color: Colors.grey[600]),
                              ),
                              SizedBox(height: 4),
                              Text(
                                item["type"] ?? "",
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                getTimeLeft(item["expiryTime"]!),
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),

                        IconButton(
                          icon: Icon(
                            favorites.contains(item["id"])
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: Colors.red,
                          ),
                          onPressed: () {
                            toggleFavorite(item["id"]!);
                          },
                        ),

                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          onPressed: item["claimed"] == "true"
                              ? null
                              : () {
                                  claimFood(item["id"]!);
                                },
                          child: Text(
                            item["claimed"] == "true"
                                ? "Claimed"
                                : "Claim",
                          ),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AddFoodScreen(addFood: addFood),
            ),
          );
        },
        child: Icon(Icons.add),
      ),
    );
  }
}