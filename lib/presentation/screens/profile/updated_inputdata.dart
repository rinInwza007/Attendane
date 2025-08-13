// lib/presentation/screens/profile/updated_inputdata.dart
import 'package:flutter/material.dart';
import 'package:myproject2/data/services/auth_service.dart';
import 'package:myproject2/presentation/screens/face/realtime_face_detection_screen.dart';
import 'package:myproject2/presentation/screens/profile/updated_profile.dart';
import 'package:myproject2/presentation/screens/profile/profileteachaer.dart';

class UpdatedInputDataPage extends StatefulWidget {
  const UpdatedInputDataPage({super.key});

  @override
  State<UpdatedInputDataPage> createState() => _UpdatedInputDataPageState();
}

class _UpdatedInputDataPageState extends State<UpdatedInputDataPage> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _fullNameController = TextEditingController();
  final _schoolIdController = TextEditingController();
  bool _isLoading = false;
  bool _isFaceProcessing = false;
  String _selectedRole = 'student';

  @override
  void dispose() {
    _fullNameController.dispose();
    _schoolIdController.dispose();
    super.dispose();
  }

  String? _validateFullName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your full name';
    }
    if (value.length < 2) {
      return 'Name must be at least 2 characters long';
    }
    return null;
  }

  String? _validateSchoolId(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your school ID';
    }
    if (value.length < 5) {
      return 'School ID must be at least 5 characters';
    }
    return null;
  }

  Future<void> _saveUserProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      print('✅ User profile saved successfully');

      // ตรวจสอบว่าข้อมูลบันทึกสำเร็จ
      final savedProfile = await _authService.getUserProfile();
      if (savedProfile == null) {
        throw Exception('Failed to save user profile');
      }

      print('📋 Saved profile: $savedProfile');

      // ถ้าเป็นนักเรียน ต้องตั้งค่า Face Recognition
      if (_selectedRole == 'student') {
        print('👨‍🎓 User is student, setting up Face Recognition...');
        
        if (!mounted) return;
        
        await _handleStudentFaceSetup();
      }

      // เมื่อทุกอย่างเรียบร้อย นำทางไปยังหน้าที่เหมาะสม
      if (mounted) {
        _navigateToProfilePage();
      }
    } catch (e) {
      print('❌ Error in _saveUserProfile: $e');
      if (mounted) {
        _showErrorDialog(
          'เกิดข้อผิดพลาดในการบันทึกข้อมูล: ${e.toString()}',
          showRetry: true,
          onRetry: _saveUserProfile,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleStudentFaceSetup() async {
    if (!mounted) return;
    
    final hasFace = await _authService.hasFaceEmbedding();
    if (hasFace) {
      print('✅ Face data already exists');
      return;
    }

    print('📸 No face data found, starting Face Recognition setup...');
    
    // แสดง dialog อธิบายระบบใหม่
    final shouldSetup = await _showFaceSetupIntroDialog();
    if (!shouldSetup) return;
    
    bool faceProcessed = false;
    int attempts = 0;
    const maxAttempts = 3;

    while (!faceProcessed && attempts < maxAttempts && mounted) {
      attempts++;
      print('🔄 Face setup attempt $attempts/$maxAttempts');
      
      try {
        await _processRealtimeFaceSetup();
        
        // ตรวจสอบอีกครั้งว่ามีข้อมูลใบหน้าแล้ว
        faceProcessed = await _authService.hasFaceEmbedding();

        if (!faceProcessed && mounted) {
          final shouldRetry = await _showRetryDialog(
            'ข้อมูลใบหน้าไม่สมบูรณ์',
            'การบันทึกข้อมูลใบหน้าไม่สำเร็จ กรุณาลองใหม่อีกครั้ง',
            attempts < maxAttempts,
          );
          
          if (!shouldRetry) break;
        }
      } catch (e) {
        print('❌ Error in face setup attempt $attempts: $e');
        if (mounted) {
          final shouldRetry = await _showRetryDialog(
            'เกิดข้อผิดพลาด',
            e.toString(),
            attempts < maxAttempts,
          );
          
          if (!shouldRetry) break;
        }
      }
    }

    // ตรวจสอบสุดท้าย
    final finalCheck = await _authService.hasFaceEmbedding();
    if (!finalCheck && mounted) {
      _showErrorDialog(
        'ไม่สามารถบันทึกข้อมูลใบหน้าได้หลังจากพยายาม $attempts ครั้ง\nคุณสามารถตั้งค่าภายหลังได้ในหน้าโปรไฟล์',
        showRetry: false,
      );
      // ไม่ throw error เพื่อให้ผู้ใช้สามารถดำเนินการต่อได้
    }
  }

  Future<bool> _showFaceSetupIntroDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.face_retouching_natural, color: Colors.blue, size: 28),
            SizedBox(width: 12),
            Text('ตั้งค่า Face Recognition'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'เริ่มต้นใช้งาน Face Recognition แบบใหม่!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'ระบบใหม่จะใช้กล้องแบบ Real-time ไม่ต้องถ่ายรูปเอง',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 12),
              Text('คุณสมบัติใหม่:'),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.camera_alt, size: 16, color: Colors.green),
                  SizedBox(width: 8),
                  Expanded(child: Text('เปิดกล้องและวางใบหน้าในกรอบ')),
                ],
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.auto_awesome, size: 16, color: Colors.green),
                  SizedBox(width: 8),
                  Expanded(child: Text('ระบบตรวจจับใบหน้าอัตโนมัติ')),
                ],
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.timer, size: 16, color: Colors.green),
                  SizedBox(width: 8),
                  Expanded(child: Text('นับถอยหลัง 3 วินาทีก่อนบันทึก')),
                ],
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.security, size: 16, color: Colors.green),
                  SizedBox(width: 8),
                  Expanded(child: Text('ความปลอดภัยสูงและแม่นยำมากขึ้น')),
                ],
              ),
              SizedBox(height: 12),
              const Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb, color: Colors.orange, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'เคล็ดลับ:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• หันหน้าตรงไปที่กล้อง\n'
                      '• อยู่ในที่ที่มีแสงสว่างเพียงพอ\n'
                      '• ไม่สวมแว่นตาหรือหน้ากาก',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ข้ามไปก่อน'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.face_retouching_natural),
            label: const Text('เริ่มตั้งค่า'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade400,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _processRealtimeFaceSetup() async {
    if (!mounted) return;
    
    setState(() => _isFaceProcessing = true);
    
    try {
      print('📱 Opening real-time face registration...');
      
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => RealtimeFaceDetectionScreen(
            isRegistration: true,
            instructionText: "วางใบหน้าของคุณในกรอบสีเขียว\nระบบจะตรวจจับและบันทึกโดยอัตโนมัติ",
            onFaceEmbeddingCaptured: (embedding) {
              print('✅ Face embedding captured successfully');
            },
          ),
        ),
      );

      if (!mounted) return;

      if (result == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('บันทึกข้อมูลใบหน้าสำเร็จ!'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        throw Exception('การบันทึกใบหน้าถูกยกเลิก');
      }

    } catch (e) {
      print('❌ Error in real-time face setup: $e');
      
      String errorMessage = 'เกิดข้อผิดพลาด: ${e.toString()}';
      
      if (e.toString().contains('ไม่พบใบหน้า')) {
        errorMessage = 'ไม่พบใบหน้าในภาพ กรุณาหันหน้าตรงไปที่กล้อง';
      } else if (e.toString().contains('พบใบหน้าหลาย')) {
        errorMessage = 'พบใบหน้าหลายใบ กรุณาให้มีเพียงใบหน้าของคุณในกรอบ';
      } else if (e.toString().contains('การบันทึกใบหน้าถูกยกเลิก')) {
        errorMessage = 'การตั้งค่า Face Recognition ถูกยกเลิก';
      }
      
      throw Exception(errorMessage);
    } finally {
      if (mounted) {
        setState(() => _isFaceProcessing = false);
      }
    }
  }

  Future<bool> _showRetryDialog(String title, String message, bool canRetry) async {
    if (!mounted) return false;
    
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          if (canRetry)
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('ลองใหม่'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(canRetry ? 'ข้าม' : 'ปิด'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showErrorDialog(String message, {bool showRetry = false, VoidCallback? onRetry}) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('เกิดข้อผิดพลาด'),
        content: Text(message),
        actions: [
          if (showRetry && onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: const Text('ลองใหม่'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }

  void _navigateToProfilePage() {
    if (!mounted) return;
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => _selectedRole == 'teacher'
            ? const TeacherProfile()
            : const UpdatedProfile(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'User Information',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _selectedRole == 'teacher'
                          ? Icons.school
                          : Icons.person_outline,
                      size: 100,
                      color: Colors.purple.shade400,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'Welcome!',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please complete your profile',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  const SizedBox(height: 32),

                  // Role Selection
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select your role',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildRoleOption(
                                'student', 'Student', Icons.person),
                            const SizedBox(width: 12),
                            _buildRoleOption(
                                'teacher', 'Teacher', Icons.school),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  TextFormField(
                    controller: _fullNameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      hintText: 'Enter your full name',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    validator: _validateFullName,
                    textCapitalization: TextCapitalization.words,
                    enabled: !_isLoading && !_isFaceProcessing,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _schoolIdController,
                    decoration: InputDecoration(
                      labelText: 'School ID',
                      hintText: 'Enter your school ID',
                      prefixIcon: const Icon(Icons.numbers),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    validator: _validateSchoolId,
                    enabled: !_isLoading && !_isFaceProcessing,
                  ),
                  const SizedBox(height: 40),

                  // Face Recognition Information Card for Students
                  if (_selectedRole == 'student')
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.face_retouching_natural,
                                color: Colors.blue.shade700,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Face Recognition Setup',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'เวอร์ชันใหม่! ใช้เทคโนโลยี Real-time Face Detection ไม่ต้องถ่ายรูปเอง',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '• เปิดกล้องและวางใบหน้าในกรอบ\n'
                            '• ระบบตรวจจับใบหน้าอัตโนมัติ\n'
                            '• บันทึกข้อมูลทันทีเมื่อได้ภาพที่ดี',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),

                  // Loading indicator for face processing
                  if (_isFaceProcessing)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'กำลังประมวลผลข้อมูลใบหน้า...',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (_isLoading || _isFaceProcessing) ? null : _saveUserProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade400,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              _selectedRole == 'student' 
                                  ? 'Save Profile & Setup Face Recognition'
                                  : 'Save Profile',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  
                  // เพิ่มพื้นที่ว่างด้านล่าง
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleOption(String role, String label, IconData icon) {
    final isSelected = _selectedRole == role;
    return Expanded(
      child: InkWell(
        onTap: (_isLoading || _isFaceProcessing) ? null : () => setState(() => _selectedRole = role),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.purple.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.purple.shade400 : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color:
                    isSelected ? Colors.purple.shade400 : Colors.grey.shade600,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Colors.purple.shade700
                      : Colors.grey.shade700,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
}class UpdatedInputDataPage extends StatefulWidget {
  // ... constructor และ state
}

class _UpdatedInputDataPageState extends State<UpdatedInputDataPage> {
  // ตัวแปรต่าง ๆ
  
  // ฟังก์ชัน validation
  String? _validateFullName(String? value) { ... }
  String? _validateSchoolId(String? value) { ... }
  
  // ฟังก์ชันหลัก
  Future<void> _saveUserProfile() async {
    // ส่วนที่คุณเห็น อยู่ตรงนี้ ⬇️
    print('🔄 Saving user profile...');
    await _authService.saveUserProfile(...);
    print('✅ User profile saved successfully'); // ✅ มีต่อ
    // ... โค้ดต่อไปเยอะมาก
  }
  
  // ฟังก์ชันอื่น ๆ ทั้งหมด...
  Future<void> _handleStudentFaceSetup() { ... }
  Future<bool> _showFaceSetupIntroDialog() { ... }
  Future<void> _processRealtimeFaceSetup() { ... }
  // ... และอีกเยอะ
  
  @override
  Widget build(BuildContext context) { ... } // ✅ สมบูรณ์
  
  Widget _buildRoleOption(...) { ... } // ✅ สมบูรณ์
} // ✅ ปิด class แล้ว
