import 'package:get/get.dart';
import 'package:myproject2/presentation/common_widgets/image_picker_screen.dart';
import 'package:myproject2/presentation/screens/class/class_detail.dart';
import 'package:myproject2/presentation/screens/profile/inputdata.dart';
import 'package:myproject2/presentation/screens/profile/profile.dart';
import 'package:myproject2/presentation/screens/profile/profileteachaer.dart';
import 'package:myproject2/presentation/screens/settings/setting.dart';
import '../screens/profile/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/splash_screen.dart';
import '../../core/constants/route_constants.dart';
import '../bindings/auth_binding.dart';
import '../bindings/class_binding.dart';

class AppPages {
  static const initial = RouteConstants.splash;

  static final routes = [
    GetPage(
      name: RouteConstants.splash,
      page: () => const SplashScreen(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: RouteConstants.login,
      page: () => const LoginScreen(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: RouteConstants.register,
      page: () => const RegisterPage(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: RouteConstants.inputData,
      page: () => const InputDataPage(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: RouteConstants.studentProfile,
      page: () => const UpdatedProfile(),
      bindings: [AuthBinding(), ClassBinding()],
    ),
    GetPage(
      name: RouteConstants.teacherProfile,
      page: () => const TeacherProfile(),
      bindings: [AuthBinding(), ClassBinding()],
    ),
    GetPage(
      name: RouteConstants.settings,
      page: () => const Setting(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: RouteConstants.classDetail,
      page: () {
        final classId = Get.parameters['classId'];
        return ClassDetailPage(classId: classId!);
      },
      binding: ClassBinding(),
    ),
    GetPage(
      name: RouteConstants.faceCapture,
      page: () => ImagePickerScreen(),
    ),
  ];
}
