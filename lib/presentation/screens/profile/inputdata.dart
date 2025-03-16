import 'package:flutter/material.dart';
import 'package:myproject2/data/services/face_recognition_service.dart';
import 'package:myproject2/presentation/common_widgets/face_capture_screen.dart';
import 'package:myproject2/presentation/screens/profile/auth_server.dart';
import 'package:myproject2/presentation/screens/profile/profile.dart';
import 'package:myproject2/presentation/screens/profile/profileteachaer.dart';

class InputDataPage extends StatefulWidget {
  const InputDataPage({super.key});

  @override
  State<InputDataPage> createState() => _InputDataPageState();
}

class _InputDataPageState extends State<InputDataPage> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthServer();
  final _fullNameController = TextEditingController();
  final _schoolIdController = TextEditingController();
  bool _isLoading = false;
  String _selectedRole = 'student'; // Default role

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

    setState(() => _isLoading = true);

    try {
      // บันทึกข้อมูลผู้ใช้
      await _authService.saveUserProfile(
        fullName: _fullNameController.text.trim(),
        schoolId: _schoolIdController.text.trim(),
        userType: _selectedRole,
      );

      // ถ้าเป็นนักเรียน ต้องถ่ายรูปก่อน
      if (_selectedRole == 'student') {
        final hasFace = await _authService.hasFaceEmbedding();
        if (!hasFace && mounted) {
          bool faceProcessed = false;
          while (!faceProcessed && mounted) {
            try {
              await _handleFaceCapture();
              // ตรวจสอบอีกครั้งว่ามีข้อมูลใบหน้าแล้ว
              faceProcessed = await _authService.hasFaceEmbedding();

              if (!faceProcessed) {
                // ถ้ายังไม่มีข้อมูลใบหน้า แสดงข้อความและให้ลองใหม่
                if (mounted) {
                  final retry = await showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => AlertDialog(
                      title: const Text('ข้อมูลใบหน้าไม่สมบูรณ์'),
                      content:
                          const Text('กรุณาถ่ายภาพใบหน้าเพื่อใช้ในการเช็คชื่อ'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('ลองใหม่'),
                        ),
                      ],
                    ),
                  );
                  if (retry != true) break;
                }
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('เกิดข้อผิดพลาด: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }

          // ตรวจสอบอีกครั้งก่อนไปหน้า Profile
          final finalCheck = await _authService.hasFaceEmbedding();
          if (!finalCheck) {
            throw Exception(
                'ไม่สามารถบันทึกข้อมูลใบหน้าได้ กรุณาลองใหม่อีกครั้ง');
          }
        }
      }

      // เมื่อทุกอย่างเรียบร้อย นำทางไปยังหน้าที่เหมาะสม
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => _selectedRole == 'teacher'
                ? const TeacherProfile()
                : const Profile(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleFaceCapture() async {
    try {
      final imagePath = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => FaceCaptureScreen(
            onImageCaptured: (path) async {
              if (path != null) {
                // แสดง loading
                setState(() => _isLoading = true);

                try {
                  // ประมวลผลใบหน้า
                  final faceService = FaceRecognitionService();
                  final embedding = await faceService.getFaceEmbedding(path);
                  faceService.dispose();

                  if (embedding == null) {
                    throw Exception(
                        'ไม่พบใบหน้าในภาพ หรือพบใบหน้ามากกว่า 1 ใบหน้า');
                  }

                  // บันทึกลงฐานข้อมูล
                  await _authService.saveFaceEmbedding(embedding);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('บันทึกข้อมูลใบหน้าสำเร็จ')),
                    );
                    Navigator.pop(context); // ปิดหน้ากล้อง
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('เกิดข้อผิดพลาด: ${e.toString()}')),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() => _isLoading = false);
                  }
                }
              }
            },
          ),
        ),
      );

      if (imagePath == null) {
        // ผู้ใช้ยกเลิกการถ่ายรูป ให้ลองใหม่
        await _handleFaceCapture();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: ${e.toString()}')),
        );
        // ให้ผู้ใช้ลองใหม่
        await _handleFaceCapture();
      }
    }
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
                    enabled: !_isLoading,
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
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveUserProfile,
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
                          : const Text(
                              'Save Profile',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
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
        onTap: () => setState(() => _selectedRole = role),
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
