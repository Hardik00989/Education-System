import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';

class StudentAssignmentScreen extends StatefulWidget {
  const StudentAssignmentScreen({super.key});

  @override
  State<StudentAssignmentScreen> createState() => _StudentAssignmentScreenState();
}

class _StudentAssignmentScreenState extends State<StudentAssignmentScreen> {
  final Color primaryTeal = const Color(0xFF008080);
  final String baseUrl = "http://localhost/school_api/api.php";

  String studentClass = "";
  String studentSubject = "";
  String studentId = "";
  String studentName = "";
  bool isLoading = true;
  List assignmentsList = [];

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        studentClass = prefs.getString('studentClass') ?? "";
        studentSubject = prefs.getString('subject') ?? "";
        studentId = prefs.getString('id') ?? "";
        studentName = prefs.getString('name') ?? "Student";
      });

      if (studentId.isNotEmpty) {
        _fetchAssignments();
      } else {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _fetchAssignments() async {
    if (studentId.isEmpty) return;
    setState(() => isLoading = true);
    try {
      final String url = "$baseUrl?action=get-student-assignments&class_name=${Uri.encodeComponent(studentClass)}&subject=${Uri.encodeComponent(studentSubject)}&student_id=$studentId";
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          setState(() {
            assignmentsList = result['data'] ?? [];
            isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
      setState(() => isLoading = false);
    }
  }

  // Teacher ki upload ki hui file dekhne ke liye
  Future<void> _viewFile(String fileName) async {
    if (fileName == "none" || fileName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No file attached")));
      return;
    }
    final String fileUrl = "http://localhost/school_api/uploads/$fileName";
    final Uri uri = Uri.parse(fileUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // Naya Function: Student ki apni submission dekhne ke liye
  Future<void> _viewMySubmission(String? fileName) async {
    if (fileName == null || fileName.isEmpty || fileName == "none") {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Submission file not found")));
      return;
    }
    final String fileUrl = "http://localhost/school_api/submissions/$fileName";
    final Uri uri = Uri.parse(fileUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _pickAndSubmit(String assignmentId) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg', 'docx'],
    );

    if (result != null) {
      PlatformFile file = result.files.first;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        var request = http.MultipartRequest('POST', Uri.parse("$baseUrl?action=submit-assignment"));
        request.fields['assignment_id'] = assignmentId;
        request.fields['student_id'] = studentId;
        request.fields['student_name'] = studentName;

        if (kIsWeb) {
          request.files.add(http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name));
        } else {
          request.files.add(await http.MultipartFile.fromPath('file', file.path!));
        }

        var response = await request.send();
        Navigator.pop(context);

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Submitted Successfully!"), backgroundColor: Colors.green),
          );
          _fetchAssignments();
        }
      } catch (e) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        title: const Text("My Assignments", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryTeal,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildInfoBar(),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: primaryTeal))
                : assignmentsList.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _fetchAssignments,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: assignmentsList.length,
                itemBuilder: (context, index) => _buildAssignmentCard(assignmentsList[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _infoItem(Icons.class_, studentClass),
          _infoItem(Icons.book, studentSubject),
        ],
      ),
    );
  }

  Widget _infoItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 18, color: primaryTeal),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text("No assignments found!", style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildAssignmentCard(dynamic item) {
    String id = item["id"].toString();
    String fileName = item["file_name"] ?? "none";
    String title = item["title"] ?? "Untitled";
    String teacher = item["teacher_name"] ?? "Teacher";
    String dueDate = item["due_date"] ?? "No Date";

    // Naya field 'submission_file' API se aayega
    String submissionFile = item["submission_file"] ?? "";
    bool isSubmitted = (item["is_submitted"].toString() != "0" && item["is_submitted"] != null);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 6, color: isSubmitted ? Colors.green : primaryTeal),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
                          ),
                          Icon(
                            isSubmitted ? Icons.check_circle : Icons.pending_actions,
                            color: isSubmitted ? Colors.green : Colors.orange,
                            size: 22,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text("Teacher: $teacher", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.calendar_month_outlined, size: 14, color: Colors.redAccent),
                          const SizedBox(width: 4),
                          Text("Due: $dueDate", style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _viewFile(fileName),
                              icon: const Icon(Icons.visibility_outlined, size: 18),
                              label: const Text("View"),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primaryTeal,
                                side: BorderSide(color: primaryTeal.withOpacity(0.5)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: isSubmitted
                                ? InkWell(
                              onTap: () => _viewMySubmission(submissionFile),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.green.withOpacity(0.5)),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.done_all, color: Colors.green, size: 18),
                                    SizedBox(width: 4),
                                    Text("My Work", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            )
                                : ElevatedButton.icon(
                              onPressed: () => _pickAndSubmit(id),
                              icon: const Icon(Icons.upload_file, size: 18),
                              label: const Text("Submit"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade700,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
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
}