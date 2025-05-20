import 'package:get/get.dart';
import '../../data/models/class_model.dart';
import '../../presentation/screens/profile/auth_server.dart'; // แก้ import
import '../../core/service_locator.dart';

class ClassController extends GetxController {
  // เปลี่ยนจาก AuthService เป็น AuthServer
  final AuthServer _authService = AuthServer();

  final RxList<ClassModel> _teacherClasses = <ClassModel>[].obs;
  final RxList<ClassModel> _studentClasses = <ClassModel>[].obs;
  final Rx<ClassModel?> _selectedClass = Rx<ClassModel?>(null);
  final RxBool _isLoading = false.obs;
  final RxString _errorMessage = ''.obs;

  List<ClassModel> get teacherClasses => _teacherClasses;
  List<ClassModel> get studentClasses => _studentClasses;
  ClassModel? get selectedClass => _selectedClass.value;
  bool get isLoading => _isLoading.value;
  String get errorMessage => _errorMessage.value;

  @override
  void onInit() {
    super.onInit();
    loadClasses();
  }

  Future<void> loadClasses() async {
    _isLoading.value = true;

    try {
      final userType = await _authService.getUserType();

      if (userType == 'teacher') {
        await loadTeacherClasses();
      } else {
        await loadStudentClasses();
      }
    } catch (e) {
      _errorMessage.value = e.toString();
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> loadTeacherClasses() async {
    try {
      final classes = await _authService.getTeacherClasses();
      
      // แปลงข้อมูลจาก List<Map<String, dynamic>> เป็น List<ClassModel>
      final classList = classes.map((classData) => ClassModel(
        id: classData['class_id'] ?? '',
        name: classData['class_name'] ?? '',
        teacherEmail: classData['teacher_email'] ?? '',
        schedule: classData['schedule'] ?? '',
        room: classData['room'] ?? '',
        inviteCode: classData['invite_code'] ?? '',
        createdAt: classData['created_at'] != null
            ? DateTime.parse(classData['created_at'])
            : DateTime.now(),
        isFavorite: false,
      )).toList();
      
      _teacherClasses.assignAll(classList);
    } catch (e) {
      _errorMessage.value = e.toString();
    }
  }

  Future<void> loadStudentClasses() async {
    try {
      final classes = await _authService.getStudentClasses();
      
      // แปลงข้อมูลจาก List<Map<String, dynamic>> เป็น List<ClassModel>
      final classList = classes.map((classData) => ClassModel(
        id: classData['id'] ?? '',
        name: classData['name'] ?? '',
        teacherEmail: classData['teacher'] ?? '',
        schedule: classData['schedule'] ?? '',
        room: classData['room'] ?? '',
        inviteCode: classData['code'] ?? '',
        createdAt: classData['joinedDate'] ?? DateTime.now(),
        isFavorite: classData['isFavorite'] ?? false,
      )).toList();
      
      _studentClasses.assignAll(classList);
    } catch (e) {
      _errorMessage.value = e.toString();
    }
  }

  Future<bool> createClass({
    required String classId,
    required String className,
    required String schedule,
    required String room,
  }) async {
    _isLoading.value = true;

    try {
      await _authService.createClass(
        classId: classId,
        className: className,
        schedule: schedule,
        room: room,
      );
      await loadTeacherClasses();
      return true;
    } catch (e) {
      _errorMessage.value = e.toString();
      return false;
    } finally {
      _isLoading.value = false;
    }
  }

  Future<bool> updateClass({
    required String classId,
    required String className,
    required String schedule,
    required String room,
  }) async {
    _isLoading.value = true;

    try {
      await _authService.updateClass(
        classId: classId,
        className: className,
        schedule: schedule,
        room: room,
      );
      await loadTeacherClasses();
      return true;
    } catch (e) {
      _errorMessage.value = e.toString();
      return false;
    } finally {
      _isLoading.value = false;
    }
  }

  Future<bool> deleteClass(String classId) async {
    _isLoading.value = true;

    try {
      await _authService.deleteClass(classId);
      await loadTeacherClasses();
      return true;
    } catch (e) {
      _errorMessage.value = e.toString();
      return false;
    } finally {
      _isLoading.value = false;
    }
  }

  Future<bool> joinClass(String inviteCode) async {
    _isLoading.value = true;

    try {
      final classDetails = await _authService.getClassByInviteCode(inviteCode);
      if (classDetails == null) {
        _errorMessage.value = 'Invalid class code';
        return false;
      }

      final email = _authService.getCurrentUserEmail();
      if (email == null) {
        _errorMessage.value = 'User not authenticated';
        return false;
      }

      // Check if already joined
      if (_studentClasses.any((c) => c.id == classDetails['class_id'])) {
        _errorMessage.value = 'You have already joined this class';
        return false;
      }

      await _authService.joinClass(
        classId: classDetails['class_id'],
        studentEmail: email,
      );

      await loadStudentClasses();
      return true;
    } catch (e) {
      _errorMessage.value = e.toString();
      return false;
    } finally {
      _isLoading.value = false;
    }
  }

  Future<bool> leaveClass(String classId) async {
    _isLoading.value = true;

    try {
      final email = _authService.getCurrentUserEmail();
      if (email == null) {
        _errorMessage.value = 'User not authenticated';
        return false;
      }

      await _authService.leaveClass(
        classId: classId,
        studentEmail: email,
      );

      await loadStudentClasses();
      return true;
    } catch (e) {
      _errorMessage.value = e.toString();
      return false;
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> selectClass(String classId) async {
    _isLoading.value = true;

    try {
      final classDetail = await _authService.getClassDetail(classId);
      if (classDetail != null) {
        // แปลงข้อมูลจาก Map<String, dynamic> เป็น ClassModel
        _selectedClass.value = ClassModel(
          id: classDetail['class_id'] ?? '',
          name: classDetail['class_name'] ?? '',
          teacherEmail: classDetail['teacher_email'] ?? '',
          schedule: classDetail['schedule'] ?? '',
          room: classDetail['room'] ?? '',
          inviteCode: classDetail['invite_code'] ?? '',
          createdAt: classDetail['created_at'] != null
              ? DateTime.parse(classDetail['created_at'])
              : DateTime.now(),
          isFavorite: false,
        );
      }
    } catch (e) {
      _errorMessage.value = e.toString();
    } finally {
      _isLoading.value = false;
    }
  }

  void toggleFavorite(String classId) {
    final index = _studentClasses.indexWhere((c) => c.id == classId);
    if (index != -1) {
      final updatedClass = ClassModel(
        id: _studentClasses[index].id,
        name: _studentClasses[index].name,
        teacherEmail: _studentClasses[index].teacherEmail,
        schedule: _studentClasses[index].schedule,
        room: _studentClasses[index].room,
        inviteCode: _studentClasses[index].inviteCode,
        createdAt: _studentClasses[index].createdAt,
        isFavorite: !_studentClasses[index].isFavorite,
      );

      _studentClasses[index] = updatedClass;
      // In a real app, this should update the database as well
    }
  }

  void clearError() {
    _errorMessage.value = '';
  }
}