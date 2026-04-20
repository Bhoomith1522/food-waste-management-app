import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'bot_helper.dart';

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final codeController = TextEditingController();
  final newPasswordController = TextEditingController();

  bool isLogin = true;
  bool isConfirming = false;
  bool isResettingPassword = false;

  // ✅ FIXED
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

  bool isValidEmailByRole(String email) {
    email = email.toLowerCase();

    if (email.endsWith("@gmail.com")) return true;

    if (selectedRole == "NGO") {
      return email.contains("ngo");
    }

    if (selectedRole == "Orphanage") {
      return email.contains("orphan");
    }

    if (selectedRole == "BlueCross") {
      return email.contains("animal");
    }

    return true;
  }

  // 🔥 FIXED LOGIN BUG HERE
  Future<void> handleAuth() async {
    try {
      String email = emailController.text.trim();
      String password = passwordController.text.trim();

      if (!isValidEmailByRole(email)) {
        _showSnack("Enter valid ${selectedRole} email");
        return;
      }

      if (isLogin) {
        // ✅ FIX: prevent "already signed in"
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
          _showSnack("Verify your account first");
        }

      } else {
        final res = await Amplify.Auth.signUp(
          username: email,
          password: password,
          options: SignUpOptions(userAttributes: {
            CognitoUserAttributeKey.email: email,
          }),
        );

        if (res.nextStep.signUpStep ==
            AuthSignUpStep.confirmSignUp) {
          setState(() => isConfirming = true);
          _showSnack("Verification code sent");
        }
      }

    } on AuthException catch (e) {
      _showSnack(e.message);
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

  // 🔑 RESET PASSWORD
  Future<void> resetPassword() async {
    try {
      await Amplify.Auth.resetPassword(
        username: emailController.text.trim(),
      );

      setState(() => isResettingPassword = true);

      _showSnack("Reset code sent");

    } catch (e) {
      _showSnack("Error sending reset code");
    }
  }

  Future<void> confirmResetPassword() async {
    try {
      await Amplify.Auth.confirmResetPassword(
        username: emailController.text.trim(),
        newPassword: newPasswordController.text.trim(),
        confirmationCode: codeController.text.trim(),
      );

      _showSnack("Password reset successful");

      setState(() {
        isResettingPassword = false;
        isLogin = true;
      });

    } catch (e) {
      _showSnack("Reset failed");
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, textAlign: TextAlign.center)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Authentication"),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),

      body: Stack(
        children: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.green.shade800],
                ),
              ),
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(25),
                        child: Column(
                          children: [

                            Text(
                              isResettingPassword
                                  ? "Reset Password"
                                  : isConfirming
                                      ? "Verify Account"
                                      : (isLogin ? "Login" : "Signup"),
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold),
                            ),

                            SizedBox(height: 20),

                            if (!isConfirming && !isResettingPassword)
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

                            TextField(
                              controller: emailController,
                              decoration: InputDecoration(labelText: "Email"),
                            ),

                            // ✅ FIXED SHOW PASSWORD
                            if (!isConfirming && !isResettingPassword)
                              TextField(
                                controller: passwordController,
                                obscureText: !showPassword,
                                decoration: InputDecoration(
                                  labelText: "Password",
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

                            if (isConfirming || isResettingPassword)
                              TextField(
                                controller: codeController,
                                decoration:
                                    InputDecoration(labelText: "Code"),
                              ),

                            if (isResettingPassword)
                              TextField(
                                controller: newPasswordController,
                                obscureText: !showPassword,
                                decoration: InputDecoration(
                                  labelText: "New Password",
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

                            SizedBox(height: 20),

                            ElevatedButton(
                              onPressed: isConfirming
                                  ? confirmUser
                                  : isResettingPassword
                                      ? confirmResetPassword
                                      : handleAuth,
                              child: Text("Continue"),
                            ),

                            if (!isConfirming && !isResettingPassword)
                              TextButton(
                                onPressed: () {
                                  setState(() => isLogin = !isLogin);
                                },
                                child: Text(isLogin
                                    ? "Signup instead"
                                    : "Login instead"),
                              ),

                            if (isLogin && !isResettingPassword)
                              TextButton(
                                onPressed: resetPassword,
                                child: Text("Forgot Password?"),
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

          BotHelper(
            messages: [
              "Login or Signup",
              "Use Gmail for testing",
              "Forgot password if needed",
            ],
          ),
        ],
      ),
    );
  }
}