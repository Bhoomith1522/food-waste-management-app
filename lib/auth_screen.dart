import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final codeController = TextEditingController();

  bool isLogin = true;
  bool isConfirming = false;
  bool showPassword = false; // 👁️ NEW

  // 🔐 LOGIN / SIGNUP
  Future<void> handleAuth() async {
  try {
    if (isLogin) {
      try {
        await Amplify.Auth.signOut();
      } catch (_) {}

      await Amplify.Auth.signIn(
        username: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      Navigator.pushReplacementNamed(context, "/home");
    } else {
      try {
        await Amplify.Auth.signUp(
          username: emailController.text.trim(),
          password: passwordController.text.trim(),
          options: SignUpOptions(userAttributes: {
            CognitoUserAttributeKey.email: emailController.text.trim(),
          }),
        );

        setState(() {
          isConfirming = true;
        });

        _showSnack("Code sent 📩");
      } catch (e) {
        if (e.toString().contains("UsernameExistsException")) {
          _showSnack("User already exists, please login");
          setState(() {
            isLogin = true;
          });
        } else {
          _showSnack("Signup failed ❌");
        }
      }
    }
  } catch (e) {
    _showSnack("Invalid credentials ❌");
  }
}


  // ✅ VERIFY CODE
  Future<void> confirmUser() async {
  try {
    await Amplify.Auth.confirmSignUp(
      username: emailController.text.trim(),
      confirmationCode: codeController.text.trim(),
    );

    _showSnack("Verified ✅");

    setState(() {
      isConfirming = false;
      isLogin = true;
    });
  } catch (e) {
    if (e.toString().contains("CodeMismatchException")) {
      _showSnack("Invalid code ❌");
    } else {
      _showSnack("Verification failed ⚠️");
    }
  }
}

  // 🔥 SMALL SNACKBAR (CUTE)
  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.symmetric(horizontal: 80, vertical: 20),
        duration: Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Food Waste App"),
        backgroundColor: Colors.green,
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isConfirming
                  ? "Verify"
                  : (isLogin ? "Login" : "Signup"),
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            SizedBox(height: 20),

            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
            ),

            SizedBox(height: 15),

            // 🔑 PASSWORD WITH TOGGLE 👁️
            if (!isConfirming)
              TextField(
                controller: passwordController,
                obscureText: !showPassword,
                decoration: InputDecoration(
                  labelText: isLogin ? "Password" : "Enter New Password",
                  border: OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      showPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        showPassword = !showPassword;
                      });
                    },
                  ),
                ),
              ),

            if (isConfirming) ...[
              SizedBox(height: 15),
              TextField(
                controller: codeController,
                decoration: InputDecoration(
                  labelText: "Verification Code",
                  border: OutlineInputBorder(),
                ),
              ),
            ],

            SizedBox(height: 20),

            ElevatedButton(
              onPressed: isConfirming ? confirmUser : handleAuth,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text(
                isConfirming
                    ? "Verify"
                    : (isLogin ? "Login" : "Signup"),
              ),
            ),

            if (!isConfirming)
              TextButton(
                onPressed: () {
                  setState(() {
                    isLogin = !isLogin;
                  });
                },
                child: Text(
                  isLogin
                      ? "Signup instead"
                      : "Login instead",
                ),
              ),
          ],
        ),
      ),
    );
  }
}