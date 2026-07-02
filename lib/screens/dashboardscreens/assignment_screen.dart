import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class AssignmentScreen extends StatefulWidget {
  const AssignmentScreen({super.key});

  @override
  State<AssignmentScreen> createState() => _AssignmentScreenState();
}

class _AssignmentScreenState extends State<AssignmentScreen> {
  final Color primaryTeal = const Color(0xFF008080);
  final String baseUrl = "http://localhost/school_api/api.php";

  String teacherSubject = "";
  String teacherClass = "";
  String teacherId = "";
  String teacherName = "";
  bool isLoading = true;
  List assignmentsFromApi = [];

  @override
  void initState() {
    super.initState();
    _loadTeacherData();
  }

  Future<void> _loadTeacherData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        teacherId = prefs.getString('id') ?? "";
        teacherName = prefs.getString('name') ?? "";
        teacherSubject = prefs.getString('subject') ?? "No Subject";
        teacherClass = prefs.getString('studentClass') ?? "No Class";
      });
      if (teacherId.isNotEmpty) {
        _fetchAssignmentsFromDb();
      } else {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _fetchAssignmentsFromDb() async {
    if (teacherId.isEmpty) return;
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse("$baseUrl?action=get-my-assignments&teacher_id=$teacherId"),
      );
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          setState(() => assignmentsFromApi = result['data'] ?? []);
        }
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Updated Custom Delete Dialog to match UI Theme
  Future<void> _deleteAssignment(String id) async {
    bool confirm = await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 40),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Delete Assignment?",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
                ),
                const SizedBox(height: 12),
                Text(
                  "Are you sure? All student submissions for this assignment will also be permanently deleted.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Delete", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      final response = await http.get(Uri.parse("$baseUrl?action=delete-assignment&id=$id"));
      final result = jsonDecode(response.body);
      if (result['success'] == true) {
        _fetchAssignmentsFromDb();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Deleted successfully"),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Delete Error: $e");
    }
  }

  Future<bool> _submitAssignmentToDb(String title, String due, PlatformFile? platformFile) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse("$baseUrl?action=create-assignment"));
      request.fields['teacher_id'] = teacherId;
      request.fields['teacher_name'] = teacherName;
      request.fields['title'] = title;
      request.fields['subject'] = teacherSubject;
      request.fields['class_name'] = teacherClass;
      request.fields['due_date'] = due;

      if (platformFile != null) {
        if (kIsWeb) {
          request.files.add(http.MultipartFile.fromBytes('file', platformFile.bytes!, filename: platformFile.name));
        } else {
          request.files.add(await http.MultipartFile.fromPath(platformFile.path != null ? 'file' : '', platformFile.path!));
        }
      }

      var streamedResponse = await request.send();
      if (streamedResponse.statusCode == 200) {
        _fetchAssignmentsFromDb();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAssignmentSheet(context, isTablet),
        backgroundColor: primaryTeal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isTablet ? 850 : double.infinity),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: _buildHeader(isTablet),
                ),
                Expanded(
                  child: isLoading
                      ? Center(child: CircularProgressIndicator(color: primaryTeal))
                      : assignmentsFromApi.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    physics: const BouncingScrollPhysics(),
                    itemCount: assignmentsFromApi.length,
                    itemBuilder: (context, index) => _buildAssignmentCard(assignmentsFromApi[index], isTablet),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Assignments",
          style: TextStyle(
            fontSize: isTablet ? 32 : 28,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2D3142),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: primaryTeal.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "$teacherSubject • $teacherClass",
            style: TextStyle(
              color: primaryTeal,
              fontWeight: FontWeight.bold,
              fontSize: isTablet ? 15 : 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.assignment_late_outlined, size: 80, color: Colors.grey.shade300),
            ),
            const SizedBox(height: 20),
            const Text(
              "No assignments yet",
              style: TextStyle(
                color: Color(0xFF2D3142),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Tap the + button to create your first\nassignment for this class.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentCard(dynamic item, bool isTablet) {
    String id = item["id"].toString();
    String title = item["title"] ?? "Untitled";
    String dueDate = item["due_date"] ?? "No Date";

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 6, color: primaryTeal),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(isTablet ? 24.0 : 18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: isTablet ? 20 : 18,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2D3142),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _deleteAssignment(id),
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Text(
                            "Due: $dueDate",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SubmissionsListScreen(
                              assignmentId: id,
                              assignmentTitle: title,
                            ),
                          ),
                        ),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: primaryTeal.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_alt_outlined, size: 18, color: primaryTeal),
                              const SizedBox(width: 8),
                              Text(
                                "View Submissions",
                                style: TextStyle(
                                  color: primaryTeal,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddAssignmentSheet(BuildContext context, bool isTablet) {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController dateController = TextEditingController();
    String selectedFileName = "";
    PlatformFile? pickedPlatformFile;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: isTablet ? 500 : double.infinity),
            padding: EdgeInsets.only(
              top: 15,
              left: 25,
              right: 25,
              bottom: MediaQuery.of(context).viewInsets.bottom + 25,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: isTablet ? BorderRadius.circular(30) : const BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 25),
                const Text("Create Assignment", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 25),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: "Assignment Title",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    prefixIcon: const Icon(Icons.edit_note),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: dateController,
                  readOnly: true,
                  onTap: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setModalState(() => dateController.text = DateFormat('dd MMM yyyy').format(picked));
                  },
                  decoration: InputDecoration(
                    labelText: "Due Date",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    prefixIcon: const Icon(Icons.event),
                  ),
                ),
                const SizedBox(height: 15),
                InkWell(
                  onTap: () async {
                    FilePickerResult? res = await FilePicker.platform.pickFiles();
                    if (res != null) setModalState(() { selectedFileName = res.files.single.name; pickedPlatformFile = res.files.single; });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.attach_file),
                        const SizedBox(width: 10),
                        Expanded(child: Text(selectedFileName.isEmpty ? "Attach Reference File" : selectedFileName, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryTeal,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: () async {
                      if (titleController.text.isNotEmpty && dateController.text.isNotEmpty) {
                        await _submitAssignmentToDb(titleController.text, dateController.text, pickedPlatformFile);
                        if (mounted) Navigator.pop(context);
                      }
                    },
                    child: const Text("Post Assignment", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SubmissionsListScreen extends StatelessWidget {
  final String assignmentId;
  final String assignmentTitle;
  const SubmissionsListScreen({super.key, required this.assignmentId, required this.assignmentTitle});

  @override
  Widget build(BuildContext context) {
    final bool isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(title: Text(assignmentTitle), backgroundColor: const Color(0xFF008080), foregroundColor: Colors.white, elevation: 0),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isTablet ? 800 : double.infinity),
          child: FutureBuilder<List>(
            future: _fetchSubmissions(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text("No submissions yet."));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data!.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  var sub = snapshot.data![index];
                  return ListTile(
                    tileColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(sub['student_name'] ?? "Student", style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("Submitted: ${sub['submitted_at']}"),
                    trailing: IconButton(
                      icon: const Icon(Icons.file_present, color: Color(0xFF008080)),
                      onPressed: () => _openFile(sub['submission_file']),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<List> _fetchSubmissions() async {
    final response = await http.get(Uri.parse("http://localhost/school_api/api.php?action=get-submissions&assignment_id=$assignmentId"));
    return jsonDecode(response.body)['data'] ?? [];
  }

  void _openFile(String fileName) async {
    final uri = Uri.parse("http://localhost/school_api/submissions/$fileName");
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}