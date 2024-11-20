import 'package:flutter/material.dart';
import 'package:myproject2/auth/auth_server.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

//get out serviced
final authService = AuthServer();

//logout
void logout() async {
  await authService.signOut();
}

class _ProfileState extends State<Profile> {
  @override
  Widget build(BuildContext context) {
    final currentEmail = authService.getCurrentUserEmail();
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        actions: const [
          IconButton(
            onPressed: logout,
            icon: Icon(Icons.logout),
          )
        ],
      ),
      body: Center(
        child: Text(currentEmail.toString()),
      ),
    );
  }
}
