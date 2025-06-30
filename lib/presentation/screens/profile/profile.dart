import 'dart:io';

import 'package:flutter/material.dart';
import 'package:myproject2/data/services/auth_service.dart';
import 'package:myproject2/data/services/face_recognition_service.dart';
import 'package:myproject2/presentation/common_widgets/image_picker_screen.dart';
import 'package:myproject2/presentation/screens/settings/setting.dart';
import 'package:myproject2/presentation/screens/attendance/simple_student_attendance_screen.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final AuthService _authService = AuthService();
  int _selectedTabIndex = 0;
  bool _isLoading = false;
  final TextEditingController _classCodeController = TextEditingController();

  // Mock data structure for joined classes
  final List<Map<String, dynamic>> _joinedClasses = [];

  final Map<String, String> _classTypes = {
    'CS101': 'Main',
    'MT201': 'Main',
    'PHY101': 'Secondary',
    'ENG201': 'Secondary',
  };

  final List<Map<String, String>> _availableClasses = [
    {
      'id': 'CS101',
      'name': 'Introduction to Programming',
      'teacher': 'John Smith',
      'code': 'CS101-2024',
      'description': 'Learn the basics of programming with Python and Java',
      'schedule': 'Mon, Wed 10:00-11:30',
      'room': 'Room 301',
      'students': '45',
      'maxStudents': '50'
    },
    {
      'id': 'MT201',
      'name': 'Advanced Mathematics',
      'teacher': 'Sarah Johnson',
      'code': 'MT201-2024',
      'description': 'Advanced topics in calculus and linear algebra',
      'schedule': 'Tue, Thu 13:00-14:30',
      'room': 'Room 405',
      'students': '38',
      'maxStudents': '40'
    },
  ];

  List<Map<String, dynamic>> get _filteredClasses {
    if (_selectedTabIndex == 0) return _joinedClasses;

    final filterType = _selectedTabIndex == 1 ? 'Main' : 'Secondary';
    return _joinedClasses
        .where((cls) => _classTypes[cls['id']] == filterType)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadClasses();
    _checkFaceDataForAttendance(); // ตรวจสอบเฉพาะเมื่อจำเป็น
  }

  Future<void> _loadClasses() async {
    setState(() => _isLoading = true);
    try {
      final classes = await _authService.getStudentClasses();
      setState(() {
        _joinedClasses.clear();
        _joinedClasses.addAll(classes);
      });
    } catch (e) {
      print('Error loading classes: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load classes. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showClassPreview(Map<String, String> classData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(classData['name'] ?? ''),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _previewInfoRow('Course ID', classData['id']),
              _previewInfoRow('Teacher', classData['teacher']),
              _previewInfoRow('Schedule', classData['schedule']),
              _previewInfoRow('Room', classData['room']),
              const SizedBox(height: 12),
              Text(
                'Description',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Text(classData['description'] ?? ''),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final userEmail = _authService.getCurrentUserEmail();
                if (userEmail == null) {
                  throw Exception('User not logged in');
                }

                await _authService.joinClass(
                  classId: classData['id']!,
                  studentEmail: userEmail,
                );

                await _loadClasses();

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Successfully joined the class!')),
                );
              } catch (e) {
                print('Error joining class: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to join class. Please try again.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade100,
              foregroundColor: Colors.purple.shade700,
            ),
            child: const Text('Join Class'),
          ),
        ],
      ),
    );
  }

  // ตรวจสอบข้อมูลใบหน้าเฉพาะเมื่อจำเป็นต่อการเข้าใช้งาน
  Future<void> _checkFaceDataForAttendance() async {
    // ไม่แสดง dialog หรือการแจ้งเตือนอัตโนมัติ
    // เฉพาะตรวจสอบเบื้องหลัง
    try {
      final hasFace = await _authService.hasFaceEmbedding();
      // บันทึกสถานะไว้ใช้ภายหลังเมื่อจำเป็น
      if (!hasFace) {
        print('ℹ️ Face data not found - user can set up later when needed');
      }
    } catch (e) {
      print('❌ Error checking face data: $e');
    }
  }

  // ฟังก์ชันสำหรับตั้งค่าข้อมูลใบหน้าเมื่อผู้ใช้ต้องการ
  Future<void> _setupFaceRecognition() async {
    final shouldSetup = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.face_retouching_natural, color: Colors.blue),
            SizedBox(width: 12),
            Text('ตั้งค่า Face Recognition'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Face Recognition จะช่วยให้การเช็คชื่อสะดวกและปลอดภัยมากขึ้น',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 12),
            Text('คุณสมบัติ:'),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.check, size: 16, color: Colors.green),
                SizedBox(width: 8),
                Expanded(child: Text('เช็คชื่อรวดเร็ว')),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.check, size: 16, color: Colors.green),
                SizedBox(width: 8),
                Expanded(child: Text('ป้องกันการโกง')),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.check, size: 16, color: Colors.green),
                SizedBox(width: 8),
                Expanded(child: Text('ความปลอดภัยสูง')),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ข้ามไปก่อน'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.photo_camera),
            label: const Text('ตั้งค่าเลย'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade400,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
    
    if (shouldSetup == true && mounted) {
      _navigateToCamera();
    }
  }

  Future<void> _navigateToCamera() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    
    try {
      print('📱 Opening face capture screen...');
      
      final String? imagePath = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => ImagePickerScreen(
            instructionText: "กรุณาเลือกรูปภาพที่เห็นใบหน้าชัดเจน ไม่สวมแว่นตา และต้องมีเพียงใบหน้าของคุณเท่านั้น",
          ),
        ),
      );

      if (!mounted) return;

      if (imagePath == null) {
        print('❌ No image selected');
        setState(() => _isLoading = false);
        return;
      }

      print('📷 Image selected: $imagePath');
      await _processFaceImage(imagePath);

    } catch (e) {
      print('❌ Error in _navigateToCamera: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('เกิดข้อผิดพลาดในการเลือกรูปภาพ: ${e.toString()}');
      }
    }
  }

  Future<void> _processFaceImage(String imagePath) async {
    if (!mounted) return;
    
    try {
      print('🔄 Processing face image: $imagePath');
      
      final file = File(imagePath);
      if (!await file.exists()) {
        throw Exception('ไม่พบไฟล์รูปภาพที่เลือก');
      }

      final fileStat = await file.stat();
      if (fileStat.size == 0) {
        throw Exception('ไฟล์รูปภาพเสียหายหรือว่างเปล่า');
      }

      print('✅ File validation passed, size: ${fileStat.size} bytes');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('กำลังประมวลผลข้อมูลใบหน้า...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      final faceService = FaceRecognitionService();
      
      try {
        print('🤖 Checking model availability...');
        
        final modelAvailable = await faceService.checkModelAvailability();
        if (!modelAvailable) {
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            _showModelUnavailableDialog();
          }
          return;
        }
        
        print('🤖 Initializing face recognition service...');
        await faceService.initialize();
        
        print('🧠 Processing face embedding...');
        final embedding = await faceService.getFaceEmbedding(imagePath);
        
        print('💾 Saving face embedding to database...');
        await _authService.saveFaceEmbedding(embedding);
        
        print('✅ Face embedding saved successfully');

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('ตั้งค่า Face Recognition สำเร็จ'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
        
      } finally {
        await faceService.dispose();
        print('🧹 Face recognition service disposed');
      }

      try {
        if (await file.exists()) {
          await file.delete();
          print('🗑️ Temporary image file deleted');
        }
      } catch (e) {
        print('⚠️ Failed to delete temporary file: $e');
      }

    } catch (e) {
      print('❌ Error in _processFaceImage: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        
        if (e.toString().contains('AI Model ไม่พร้อมใช้งาน')) {
          _showModelUnavailableDialog();
        } else {
          String errorMessage = 'เกิดข้อผิดพลาด: ${e.toString()}';
          
          if (e.toString().contains('ไม่พบใบหน้า')) {
            errorMessage = 'ไม่พบใบหน้าในรูปภาพ กรุณาเลือกรูปที่เห็นใบหน้าชัดเจน';
          } else if (e.toString().contains('พบใบหน้าหลาย')) {
            errorMessage = 'พบใบหน้าหลายใบในรูปภาพ กรุณาเลือกรูปที่มีเพียงใบหน้าของคุณเท่านั้น';
          }
          
          _showRetrySnackBar(errorMessage);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showModelUnavailableDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 12),
            Text('ระบบ AI ไม่พร้อมใช้งาน'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ระบบ Face Recognition ไม่พร้อมใช้งานในขณะนี้',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 12),
            Text('สาเหตุที่เป็นไปได้:'),
            SizedBox(height: 8),
            Text('• ไฟล์ AI Model หายไป'),
            Text('• อุปกรณ์ไม่รองรับ'),
            Text('• แอปไม่ได้ติดตั้งอย่างสมบูรณ์'),
            SizedBox(height: 12),
            Text(
              'คุณยังสามารถใช้แอปได้ปกติ แต่จะไม่สามารถเช็คชื่อด้วย Face Recognition ได้',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('เข้าใจแล้ว'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToCamera();
            },
            child: const Text('ลองใหม่'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showRetrySnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'ลองใหม่',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            _navigateToCamera();
          },
        ),
      ),
    );
  }

  Widget _previewInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value ?? 'N/A'),
          ),
        ],
      ),
    );
  }

  void _handleSearch(String code, StateSetter setState,
      String? Function(String) updateError) async {
    if (code.isEmpty) {
      setState(() => updateError('Please enter a class code'));
      return;
    }

    try {
      final classDetails = await _authService.getClassByInviteCode(code);

      if (classDetails == null) {
        setState(() => updateError('The class code is not valid.'));
        return;
      }

      final classToJoin = {
        'id': classDetails['class_id']?.toString() ?? '',
        'name': classDetails['class_name']?.toString() ?? '',
        'teacher': classDetails['teacher_email']?.toString() ?? '',
        'code': code,
        'schedule': classDetails['schedule']?.toString() ?? '',
        'room': classDetails['room']?.toString() ?? '',
        'description': 'Join this class to start learning',
        'students': '0',
        'maxStudents': '50'
      };

      final userEmail = _authService.getCurrentUserEmail();
      if (userEmail == null) {
        setState(() => updateError('You must be logged in to join a class'));
        return;
      }

      if (_joinedClasses.any((c) => c['id'] == classDetails['class_id'])) {
        setState(() => updateError('You have already joined this class'));
        return;
      }

      _classCodeController.clear();
      Navigator.pop(context);
      _showClassPreview(classToJoin);
    } catch (e) {
      print('Error searching class: $e');
      setState(() => updateError('Error checking class code'));
    }
  }

  void _searchClass() {
    String? errorText;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Join Class'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _classCodeController,
                decoration: InputDecoration(
                  labelText: 'Enter Class Code',
                  hintText: 'e.g., CS101-2024',
                  errorText: errorText,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) {
                  if (errorText != null) {
                    setState(() => errorText = null);
                  }
                },
                onSubmitted: (value) {
                  _handleSearch(value, setState, (msg) => errorText = msg);
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final code = _classCodeController.text.trim();
                    _handleSearch(code, setState, (msg) => errorText = msg);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade100,
                    foregroundColor: Colors.purple.shade700,
                  ),
                  child: const Text('Search'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _leaveClass(int index) {
    final classData = _joinedClasses[index];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Class'),
        content: Text('Are you sure you want to leave ${classData['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final userEmail = _authService.getCurrentUserEmail();
                if (userEmail == null) {
                  throw Exception('User not logged in');
                }

                await _authService.leaveClass(
                  classId: classData['id'],
                  studentEmail: userEmail,
                );

                await _loadClasses();

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Successfully left the class'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                print('Error leaving class: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to leave class. Please try again.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  void _toggleFavorite(int index) {
    setState(() {
      _joinedClasses[index]['isFavorite'] =
          !_joinedClasses[index]['isFavorite'];
    });
  }

  // ปุ่มสำหรับไปหน้าเช็คชื่อ
  void _goToAttendance(Map<String, dynamic> classData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SimpleStudentAttendanceScreen(
          classId: classData['id'],
          className: classData['name'],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  void dispose() {
    _classCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentEmail = _authService.getCurrentUserEmail();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Student Home',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          // ปุ่มตั้งค่า Face Recognition
          IconButton(
            icon: const Icon(Icons.face_retouching_natural),
            onPressed: _setupFaceRecognition,
            tooltip: 'Setup Face Recognition',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const Setting()),
            ).then((_) => setState(() {})),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildProfileHeader(currentEmail),
                const SizedBox(height: 16),
                _buildTabBar(),
                const SizedBox(height: 16),
                _buildClassList(),
                _buildJoinClassButton(),
              ],
            ),
    );
  }

  Widget _buildClassList() {
    final displayedClasses = _filteredClasses;
    return Expanded(
      child: displayedClasses.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.school_outlined,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No classes joined yet',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Join a class to get started!',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: displayedClasses.length,
              itemBuilder: (context, index) => _buildClassCard(index),
            ),
    );
  }

  Widget _buildClassCard(int index) {
    final classData = _filteredClasses[index];
    final joinedDate = classData['joinedDate'] as DateTime;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      classData['id']?.substring(0, 2) ?? 'NA',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classData['id'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        classData['name'] ?? '',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Teacher: ${classData['teacher']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    // ปุ่มเช็คชื่อ
                    IconButton(
                      icon: const Icon(
                        Icons.how_to_reg,
                        color: Colors.green,
                      ),
                      onPressed: () => _goToAttendance(classData),
                      tooltip: 'Check Attendance',
                    ),
                    IconButton(
                      icon: Icon(
                        classData['isFavorite']
                            ? Icons.star
                            : Icons.star_border,
                        color: classData['isFavorite']
                            ? Colors.amber
                            : Colors.grey,
                      ),
                      onPressed: () => _toggleFavorite(index),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.exit_to_app,
                        color: Colors.red,
                      ),
                      onPressed: () => _leaveClass(index),
                      tooltip: 'Leave Class',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Joined on: ${_formatDate(joinedDate)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinClassButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: _searchClass,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple.shade100,
          foregroundColor: Colors.purple.shade700,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline),
            SizedBox(width: 8),
            Text(
              'Join Class',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(String? email) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.purple.shade200,
            child: const Icon(Icons.person, size: 35, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Student',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email ?? 'No email',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.purple.shade700,
                  ),
                ),
              ],
            ),
          ),
          // แสดงสถานะ Face Recognition แบบง่าย
          FutureBuilder<bool>(
            future: _authService.hasFaceEmbedding(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              }
              
              final hasFace = snapshot.data ?? false;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: hasFace ? Colors.green.shade100 : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasFace ? Icons.face : Icons.face_retouching_off,
                      size: 16,
                      color: hasFace ? Colors.green.shade700 : Colors.orange.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasFace ? 'Ready' : 'Setup',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: hasFace ? Colors.green.shade700 : Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final tabs = ['All Classes', 'Main Classes', 'Secondary Classes'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final text = entry.value;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: index == 1 ? 8 : 0,
              ),
              child: _buildTabButton(text, index),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabButton(String text, int index) {
    final isSelected = _selectedTabIndex == index;
    return ElevatedButton(
      onPressed: () => setState(() => _selectedTabIndex = index),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isSelected ? Colors.purple.shade100 : Colors.grey.shade100,
        elevation: isSelected ? 2 : 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isSelected ? Colors.purple.shade700 : Colors.grey.shade700,
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}