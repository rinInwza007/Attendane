import 'package:get/get.dart';
import '../../data/models/user_model.dart';
import '../../presentation/screens/profile/auth_server.dart'; // แก้ import

class AuthController extends GetxController {
  // เปลี่ยนจาก AuthService เป็น AuthServer
  final AuthServer _authService = AuthServer();

  final Rx<UserModel?> _currentUser = Rx<UserModel?>(null);
  final RxBool _isAuthenticated = false.obs;
  final RxBool _isLoading = false.obs;
  final RxString _errorMessage = ''.obs;

  UserModel? get currentUser => _currentUser.value;
  bool get isAuthenticated => _isAuthenticated.value;
  bool get isLoading => _isLoading.value;
  String get errorMessage => _errorMessage.value;

  @override
  void onInit() {
    super.onInit();
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    _isLoading.value = true;

    try {
      final email = _authService.getCurrentUserEmail();
      if (email != null) {
        await loadUserProfile();
      } else {
        _isAuthenticated.value = false;
        _currentUser.value = null;
      }
    } catch (e) {
      _errorMessage.value = e.toString();
      _isAuthenticated.value = false;
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> loadUserProfile() async {
    try {
      // ตรวจสอบชื่อเมธอดให้ถูกต้อง (อาจต้องเปลี่ยนจาก getUserProfile เป็น checkUserProfileExists หรืออื่นๆ)
      final userProfile = await _authService.getUserProfile();
      if (userProfile != null) {
        // แปลงข้อมูลจาก Map เป็น UserModel
        _currentUser.value = UserModel(
          email: userProfile['email'] ?? '',
          fullName: userProfile['full_name'] ?? '',
          schoolId: userProfile['school_id'] ?? '',
          userType: userProfile['user_type'] ?? '',
          hasFaceData: await _authService.hasFaceEmbedding(),
        );
        _isAuthenticated.value = true;
      } else {
        _isAuthenticated.value = false;
      }
    } catch (e) {
      _errorMessage.value = e.toString();
      _isAuthenticated.value = false;
    }
  }

  Future<bool> signIn(String email, String password) async {
    _isLoading.value = true;
    _errorMessage.value = '';

    try {
      // แก้ไขชื่อเมธอดให้ตรงกับที่มีใน AuthServer
      await _authService.siginWithEmailPassword(email, password);
      await loadUserProfile();
      return true;
    } catch (e) {
      _errorMessage.value = e.toString();
      return false;
    } finally {
      _isLoading.value = false;
    }
  }

  Future<bool> signUp(String email, String password) async {
    _isLoading.value = true;
    _errorMessage.value = '';

    try {
      // แก้ไขชื่อเมธอดให้ตรงกับที่มีใน AuthServer
      await _authService.sigUpWithEmailPassword(email, password);
      return true;
    } catch (e) {
      _errorMessage.value = e.toString();
      return false;
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> signOut() async {
    _isLoading.value = true;

    try {
      await _authService.signOut();
      _isAuthenticated.value = false;
      _currentUser.value = null;
    } catch (e) {
      _errorMessage.value = e.toString();
    } finally {
      _isLoading.value = false;
    }
  }

  Future<bool> saveUserProfile({
    required String fullName,
    required String schoolId,
    required String userType,
  }) async {
    _isLoading.value = true;

    try {
      await _authService.saveUserProfile(
        fullName: fullName,
        schoolId: schoolId,
        userType: userType,
      );
      await loadUserProfile();
      return true;
    } catch (e) {
      _errorMessage.value = e.toString();
      return false;
    } finally {
      _isLoading.value = false;
    }
  }

  Future<bool> hasFaceData() async {
    try {
      return await _authService.hasFaceEmbedding();
    } catch (e) {
      _errorMessage.value = e.toString();
      return false;
    }
  }

  Future<bool> saveFaceData(List<double> embedding) async {
    _isLoading.value = true;

    try {
      await _authService.saveFaceEmbedding(embedding);
      await loadUserProfile();
      return true;
    } catch (e) {
      _errorMessage.value = e.toString();
      return false;
    } finally {
      _isLoading.value = false;
    }
  }

  void clearError() {
    _errorMessage.value = '';
  }
}