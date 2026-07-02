import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const String BASE_URL = "http://localhost/school_api";

class FeedbackScreen extends StatefulWidget {
  final String studentId;
  final String studentClass;

  const FeedbackScreen({super.key, required this.studentId, required this.studentClass});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final TextEditingController _feedbackController = TextEditingController();
  String? teacherId;
  String teacherName = "Searching...";
  bool isLoading = true;
  int _selectedRating = 1;

  @override
  void initState() {
    super.initState();
    _fetchTeacherInfo();
  }

  Future<void> _fetchTeacherInfo() async {
    try {
      final response = await http.get(Uri.parse(
          "$BASE_URL/api.php?action=get-my-class-teacher&studentClass=${widget.studentClass}"));

      if (response.statusCode == 200) {
        final res = jsonDecode(response.body);
        if (res['success']) {
          setState(() {
            teacherId = res['data']['teacher_id'].toString();
            teacherName = res['data']['teacher_name'];
            isLoading = false;
          });
        } else {
          setState(() {
            teacherName = "No teacher assigned";
            isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        teacherName = "Connection Error";
        isLoading = false;
      });
    }
  }

  Future<void> _submitFeedback() async {
    final String messageText = _feedbackController.text.trim();
    if (messageText.isEmpty || teacherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please write something first!")),
      );
      return;
    }

    try {
      final int submittedRating = _selectedRating;
      final response = await http.post(
        Uri.parse("$BASE_URL/api.php?action=submit-teacher-feedback"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "student_id": widget.studentId,
          "student_class": widget.studentClass,
          "teacher_id": teacherId,
          "message": messageText,
          "rating": _selectedRating,
        }),
      );

      final res = jsonDecode(response.body);

      if (res['success']) {
        _feedbackController.clear();
        setState(() => _selectedRating = 1);
        if (!mounted) return;
        _showModernDialog(submittedRating);
      } else {
        // --- 15 Days Limit handle karne ke liye ---
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? "Error occurred"),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Server error occurred")),
      );
    }
  }

  void _showModernDialog(int submittedRating) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.teal, size: 60),
                  const SizedBox(height: 20),
                  const Text("Feedback Sent!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  const Text("You rated your teacher:"),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) => Icon(
                      index < submittedRating ? Icons.star : Icons.star_border,
                      color: Colors.amber, size: 28,
                    )),
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () { Navigator.pop(context); Navigator.pop(context); },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("BACK TO HOME", style: TextStyle(fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Teacher Feedback", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.teal,
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Class Teacher Details", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
                const SizedBox(height: 10),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal.withOpacity(0.1),
                      child: const Icon(Icons.person, color: Colors.teal),
                    ),
                    title: Text(teacherName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    subtitle: Text("Class: ${widget.studentClass}"),
                    trailing: const Icon(Icons.verified_user, color: Colors.green, size: 20),
                  ),
                ),
                const SizedBox(height: 30),
                const Text("How was your experience?", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      onPressed: () => setState(() => _selectedRating = index + 1),
                      icon: Icon(
                        index < _selectedRating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: screenWidth < 400 ? 30 : 40,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
                  ),
                  child: TextField(
                    controller: _feedbackController,
                    maxLines: 6,
                    decoration: InputDecoration(
                      hintText: "Tell us about the teaching, behavior, or any issues...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.all(20),
                      fillColor: Colors.white,
                      filled: true,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: teacherId == null ? null : _submitFeedback,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 3,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send_rounded),
                        SizedBox(width: 10),
                        Text("SUBMIT FEEDBACK", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // --- Limit ki info dene ke liye chhota note ---
                const Center(
                  child: Text(
                    "Note: Feedback can only be submitted once every 15 days.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 5),
                const Center(
                  child: Text("Your feedback is anonymous and helps us improve.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}