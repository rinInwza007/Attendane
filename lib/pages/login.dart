import 'package:flutter/material.dart';
import 'package:myproject2/auth/auth_server.dart';
import 'package:myproject2/pages/regis.dart';

class Loginpage extends StatefulWidget {
  const Loginpage({super.key});

  Duration get loadingTime => const Duration(milliseconds: 2000);

  @override
  State<Loginpage> createState() => _LoginpageState();
}

class _LoginpageState extends State<Loginpage> {
  // get auth service
  final authService = AuthServer();

  //text controller
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

//login button pressed
  void login() async {
    //prepare data
    final email = _emailController.text;
    final password = _passwordController.text;
    try {
      await authService.siginWithEmailPassword(email, password);
    }

    //catch any errors
    catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error: $e"),
        ));
      }
    }
  }

  //attemp login
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(""),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text(
              "Attendane Plus",
              style: TextStyle(
                  fontSize: 45,
                  color: Colors.purple,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(
              height: 115,
            ),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            const SizedBox(
              height: 20,
            ),
            ElevatedButton(
              onPressed: login,
              child: const Text("Login"),
            ),
            const SizedBox(
              height: 20,
            ),
            GestureDetector(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const Registerpage(),
                  )),
              child: const Center(
                child: Text("No accout? Sign Up"),
              ),
            )
          ])
        ],
      ),
    );
  }
}
