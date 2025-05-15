import 'package:flutter/material.dart';
import 'package:myproject2/data/services/face_recognition_service.dart';
import 'package:myproject2/presentation/common_widgets/image_picker_screen.dart';
import 'package:myproject2/presentation/screens/profile/auth_server.dart';
import 'package:myproject2/presentation/screens/settings/setting.dart';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final AuthServer _authService = AuthServer();
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
    _loadClasses(); // เรียกโหลดข้อมูลคลาสเมื่อเปิดหน้า
    _checkFaceData();
  }

  Future<void> _loadClasses() async {
    setState(() => _isLoading = true);
    try {
      final classes = await _authService.getStudentClasses();
      setState(() {
        _joinedClasses.clear(); // ล้างข้อมูลเก่า
        _joinedClasses.addAll(classes); // เพิ่มข้อมูลใหม่
      });
    } catch (e) {
      print('Error loading classes: $e');
      // อาจจะแสดง error message ให้ผู้ใช้
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

                // หลังจาก join สำเร็จ ให้โหลดข้อมูลใหม่
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

  Future<void> _checkFaceData() async {
    try {
      final hasFace = await _authService.hasFaceEmbedding();
      if (!hasFace && mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('ข้อมูลไม่ครบถ้วน'),
            content: const Text(
                'คุณยังไม่ได้บันทึกข้อมูลใบหน้า กรุณาเลือกรูปภาพใบหน้าเพื่อใช้ในการเช็คชื่อ'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _navigateToCamera();
                },
                child: const Text('เลือกรูปภาพ'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('เกิดข้อผิดพลาดในการตรวจสอบข้อมูล: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _navigateToCamera() async {
    try {
      // ไม่เรียก callback onImageCaptured เพื่อหลีกเลี่ยงปัญหา widget lifecycle
      final String? imagePath = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => ImagePickerScreen(
            instructionText: "กรุณาเลือกรูปภาพที่เห็นใบหน้าชัดเจน ไม่สวมแว่นตา และต้องมีเพียงใบหน้าของคุณเท่านั้น",
          ),
        ),
      );

      // ทำงานต่อเมื่อได้รับรูปภาพกลับมา
      if (imagePath != null && mounted) {
        setState(() => _isLoading = true);
        
        try {
          // ประมวลผลใบหน้า
          final faceService = FaceRecognitionService();
          await faceService.initialize();
          final embedding = await faceService.getFaceEmbedding(imagePath);
          await faceService.dispose();

          // บันทึกลงฐานข้อมูล
          await _authService.saveFaceEmbedding(embedding);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('บันทึกข้อมูลใบหน้าสำเร็จ')),
            );
            setState(() {}); // Refresh UI to update face data section
          }
        } catch (e) {
          if (mounted) {
            String errorMessage = 'เกิดข้อผิดพลาด: ${e.toString()}';
            
            if (e.toString().contains('ไม่พบใบหน้า')) {
              errorMessage = 'ไม่พบใบหน้าในรูปภาพ กรุณาเลือกรูปที่เห็นใบหน้าชัดเจน';
            } else if (e.toString().contains('พบใบหน้าหลาย')) {
              errorMessage = 'พบใบหน้าหลายใบในรูปภาพ กรุณาเลือกรูปที่มีเพียงใบหน้าของคุณเท่านั้น';
            }
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'ลองใหม่',
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    _navigateToCamera();
                  },
                ),
              ),
            );
          }
        } finally {
          if (mounted) {
            setState(() => _isLoading = false);
          }
        }
      } else if (mounted) {
        // ถ้าผู้ใช้ยกเลิก ให้ตรวจสอบอีกครั้ง
        await Future.delayed(const Duration(seconds: 1));
        _checkFaceData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('เกิดข้อผิดพลาดในการเลือกรูปภาพ: ${e.toString()}')),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _getFaceEmbeddingDetails() async {
  try {
    final email = _authService.getCurrentUserEmail();
    if (email == null) return null;
    
    try {
      // เข้าถึง Supabase.instance.client แทน _authService._supabase
      final response = await Supabase.instance.client
          .from('student_face_embeddings')
          .select('id, face_quality, created_at, updated_at')
          .eq('student_id', email)  // ใช้ email เป็น student_id ชั่วคราว
          .eq('is_active', true)
          .single();
      
      return response;
    } catch (e) {
      print('Error fetching face details: $e');
      return null;
    }
  } catch (e) {
    print('Error in _getFaceEmbeddingDetails: $e');
    return null;
  }
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
    // Check if code is empty
    if (code.isEmpty) {
      setState(() => updateError('Please enter a class code'));
      return;
    }

    try {
      // ใช้ invite_code ในการค้นหาคลาส
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
        'description':
            'Join this class to start learning', // Default description
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

                // เรียกใช้ leaveClass function
                await _authService.leaveClass(
                  classId: classData['id'],
                  studentEmail: userEmail,
                );

                // รีโหลดข้อมูลคลาสหลังจากออกสำเร็จ
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

  Future<void> _deactivateFaceEmbedding() async {
  try {
    final email = _authService.getCurrentUserEmail();
    if (email == null) return;
    
    // เข้าถึง Supabase โดยตรง
    await Supabase.instance.client
        .from('student_face_embeddings')
        .update({
          'is_active': false,
          'updated_at': DateTime.now().toIso8601String()
        })
        .eq('student_id', email);  // ใช้ email เป็น student_id ชั่วคราว
    
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ลบข้อมูลใบหน้าเรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการลบข้อมูลใบหน้า: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

  void _toggleFavorite(int index) {
    setState(() {
      _joinedClasses[index]['isFavorite'] =
          !_joinedClasses[index]['isFavorite'];
    });
  }

  Widget _buildFaceDataInfo() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _getFaceEmbeddingDetails(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final faceData = snapshot.data;
        
        if (faceData == null) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ข้อมูลใบหน้า',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text('ไม่มีข้อมูลใบหน้า',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _navigateToCamera,
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('เพิ่มข้อมูลใบหน้า'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        // คำนวณคุณภาพเป็นเปอร์เซ็นต์
        final quality = faceData['face_quality'] ?? 0.0;
        final qualityPercent = (quality * 100).toStringAsFixed(0);
        
        // แปลงวันที่
        final updatedAt = faceData['updated_at'] != null
            ? DateTime.parse(faceData['updated_at']).toLocal()
            : null;
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ข้อมูลใบหน้า',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    const Text('คุณภาพภาพใบหน้า: '),
                    const SizedBox(width: 8),
                    _buildQualityIndicator(quality),
                    const SizedBox(width: 8),
                    Text('$qualityPercent%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getQualityColor(quality),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                if (updatedAt != null)
                  Text('อัปเดตล่าสุด: ${_formatDate(updatedAt)}'),
                
                const SizedBox(height: 16),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _navigateToCamera,
                      icon: const Icon(Icons.refresh),
                      label: const Text('อัปเดตใหม่'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _deactivateFaceEmbedding,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('ลบข้อมูล'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade100,
                        foregroundColor: Colors.red.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQualityIndicator(double quality) {
    Color color = _getQualityColor(quality);
    
    return Container(
      width: 100,
      height: 10,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: Colors.grey.shade200,
      ),
      child: FractionallySizedBox(
        widthFactor: quality,
        alignment: Alignment.centerLeft,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: color,
          ),
        ),
      ),
    );
  }

  Color _getQualityColor(double quality) {
    if (quality >= 0.9) {
      return Colors.green;
    } else if (quality >= 0.7) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
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
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const Setting()),
            ).then((_) => setState(() {})), // Refresh when returning
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildProfileHeader(currentEmail),
                _buildFaceDataInfo(),
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