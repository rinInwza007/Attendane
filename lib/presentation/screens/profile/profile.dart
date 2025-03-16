import 'package:flutter/material.dart';
import 'package:myproject2/data/services/face_recognition_service.dart';
import 'package:myproject2/presentation/common_widgets/face_capture_screen.dart';
import 'package:myproject2/presentation/screens/profile/auth_server.dart';
import 'package:myproject2/presentation/screens/settings/setting.dart';

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
                'คุณยังไม่ได้บันทึกข้อมูลใบหน้า กรุณาถ่ายภาพเพื่อใช้ในการเช็คชื่อ'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _navigateToCamera();
                },
                child: const Text('ถ่ายรูป'),
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
      final String? result = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => FaceCaptureScreen(
            onImageCaptured: (String path) async {
              if (mounted) {
                setState(() => _isLoading = true);
                try {
                  final faceService = FaceRecognitionService();
                  final embedding = await faceService.getFaceEmbedding(path);
                  faceService.dispose();

                  if (embedding == null) {
                    throw Exception(
                        'ไม่พบใบหน้าในภาพ หรือพบใบหน้ามากกว่า 1 ใบหน้า');
                  }

                  await _authService.saveFaceEmbedding(embedding);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('บันทึกข้อมูลใบหน้าสำเร็จ')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('เกิดข้อผิดพลาด: ${e.toString()}')),
                    );
                  }
                  // รอสักครู่ก่อนเปิดกล้องใหม่
                  await Future.delayed(const Duration(seconds: 1));
                  if (mounted) {
                    _navigateToCamera();
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

      if (result == null) {
        // ถ้าผู้ใช้ยกเลิก ให้ตรวจสอบอีกครั้ง
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          _checkFaceData();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('เกิดข้อผิดพลาดในการเปิดกล้อง: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _captureImage() async {
    try {
      final imagePath = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => FaceCaptureScreen(
            onImageCaptured: (path) async {
              if (path != null) {
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
                  // ให้ลองใหม่ถ้าเกิดข้อผิดพลาด
                  _captureImage();
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
        // ถ้าผู้ใช้ยกเลิก ให้ตรวจสอบอีกครั้ง
        _checkFaceData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: ${e.toString()}')),
        );
        // ให้ลองใหม่
        _captureImage();
      }
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

  void _toggleFavorite(int index) {
    setState(() {
      _joinedClasses[index]['isFavorite'] =
          !_joinedClasses[index]['isFavorite'];
    });
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
            ),
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
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
