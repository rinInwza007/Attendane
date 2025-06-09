import 'package:get/get.dart';
import 'package:get_it/get_it.dart';
import 'package:myproject2/data/services/auth_service.dart';
import 'package:myproject2/data/services/face_recognition_service.dart';
import '../presentation/controllers/auth_controller.dart';
import '../presentation/controllers/class_controller.dart';

final getIt = GetIt.instance;
// In setupServiceLocator()
void setupServiceLocator() {
  // Register services as singletons
  getIt.registerLazySingleton<AuthService>(() => AuthService());
  getIt.registerLazySingleton<FaceRecognitionService>(
      () => FaceRecognitionService());

  // Register controllers
  Get.put(AuthController());
  Get.put(ClassController());
}
