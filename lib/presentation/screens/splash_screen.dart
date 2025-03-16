import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/route_constants.dart';
import '../controllers/auth_controller.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthController _authController = Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 2)); // Splash delay
    await _authController.checkAuthStatus();

    if (_authController.isAuthenticated) {
      if (_authController.currentUser != null) {
        final userType = _authController.currentUser!.userType;

        if (userType == 'teacher') {
          Get.offAllNamed(RouteConstants.teacherProfile);
        } else {
          Get.offAllNamed(RouteConstants.studentProfile);
        }
      } else {
        Get.offAllNamed(RouteConstants.inputData);
      }
    } else {
      Get.offAllNamed(RouteConstants.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.access_time_rounded,
              size: 100,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 24),
            Text(
              "Attendance Plus",
              style: TextStyle(
                fontSize: 32,
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
