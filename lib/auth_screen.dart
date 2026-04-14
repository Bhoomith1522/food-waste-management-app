import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'bot_helper.dart'; // ✅ ADD THIS

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final codeController = TextEditingController();

  bool isLogin = true;
  bool isConfirming = false;
  bool showPassword = false;

  String selectedRole = "NGO";
  final List<String> roles = ["NGO", "Orphanage", "BlueCross"];

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller =
        AnimationController(vsync: this, duration: Duration(milliseconds: 700));

    _fadeAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool isValidNGOEmail(String email) {
    final keywords = ["donate", "donation", "charity", "help", "save", "hunger"];
    email = email.toLowerCase();
    return keywords.any((word) => email.contains(word));
  }

  Future<void> handleAuth() async {
    try {
      String email = emailController.text.trim();
      String password = passwordController.text.trim();

      if (!isValidNGOEmail(email)) {
        _showSnack("Use NGO-type email");
        return;
      }

      if (isLogin) {
        try {
          await Amplify.Auth.signOut();
        } catch (_) {}

        final res = await Amplify.Auth.signIn(
          username: email,
          password: password,
        );

        if (res.isSignedIn) {
          Navigator.pushReplacementNamed(context, "/home");
        } else {
          _showSnack("Please verify your account first ⚠️");
        }
      } else {
        final res = await Amplify.Auth.signUp(
          username: email,
          password: password,
          options: SignUpOptions(userAttributes: {
            CognitoUserAttributeKey.email: email,
          }),
        );

        if (res.nextStep.signUpStep == AuthSignUpStep.confirmSignUp) {
          setState(() => isConfirming = true);
          _showSnack("Verification code sent 📩");
        } else {
          _showSnack("Signup complete, please login");
          setState(() => isLogin = true);
        }
      }
    } on AuthException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack("Something went wrong ❌");
    }
  }

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
    } on AuthException catch (e) {
      _showSnack(e.message);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.symmetric(horizontal: 80, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      // ✅ WRAPPED WITH STACK
      body: Stack(
        children: [

          FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.green.shade800],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Card(
                      elevation: 12,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(25),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [

                            CircleAvatar(
                              radius: 35,
                              backgroundColor: Colors.green.shade100,
                              child: Icon(Icons.eco,
                                  size: 40, color: Colors.green),
                            ),

                            SizedBox(height: 20),

                            Text(
                              isConfirming
                                  ? "Verify Account"
                                  : (isLogin ? "Welcome Back" : "Create Account"),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            SizedBox(height: 20),

                            if (!isConfirming)
                              DropdownButtonFormField<String>(
                                value: selectedRole,
                                items: roles.map((role) {
                                  return DropdownMenuItem(
                                    value: role,
                                    child: Text(role),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() => selectedRole = value!);
                                },
                              ),

                            SizedBox(height: 15),

                            TextField(
                              controller: emailController,
                              decoration: InputDecoration(
                                labelText: "Email",
                                prefixIcon: Icon(Icons.email),
                              ),
                            ),

                            SizedBox(height: 15),

                            if (!isConfirming)
                              TextField(
                                controller: passwordController,
                                obscureText: !showPassword,
                                decoration: InputDecoration(
                                  labelText: "Password",
                                  prefixIcon: Icon(Icons.lock),
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
                                  prefixIcon: Icon(Icons.verified),
                                ),
                              ),
                            ],

                            SizedBox(height: 20),

                            ElevatedButton(
                              onPressed:
                                  isConfirming ? confirmUser : handleAuth,
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
                                      ? "New user? Signup"
                                      : "Already have an account? Login",
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 🤖 BOT GUIDE
          BotHelper(
            messages: [
              "Welcome 👋",
              "Select your role (NGO / Orphanage / BlueCross)",
              "Enter your email and password",
              "Signup if new or login if existing",
              "Verify using code if required",
            ],
          ),
        ],
      ),
    );
  }
}