import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DoubtScreen extends StatefulWidget {
  const DoubtScreen({super.key});

  @override
  State<DoubtScreen> createState() => _DoubtScreenState();
}

class _DoubtScreenState extends State<DoubtScreen> {
  final Color primaryTeal = const Color(0xFF008080);
  final TextEditingController _doubtController = TextEditingController();

  List<dynamic> teacherData = [];
  List<dynamic> myDoubts = []; // For Chat History
  Map<String, dynamic>? selectedTeacher;
  bool isLoading = true;
  bool isSending = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _fetchMatchedTeacher();
    await _fetchMyDoubts();
  }

  /// --- FETCH TEACHER BASED ON STUDENT CLASS & SUBJECT ---
  Future<void> _fetchMatchedTeacher() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String myClass = prefs.getString('studentClass') ?? '';
    String mySubject = prefs.getString('subject') ?? '';

    try {
      final response = await http.get(Uri.parse(
          "http://localhost/school_api/api.php?action=get-matched-teachers&studentClass=$myClass&studentSubject=$mySubject"));

      final data = json.decode(response.body);
      if (data['success'] && data['data'].isNotEmpty) {
        setState(() {
          teacherData = data['data'];
          selectedTeacher = teacherData[0];
          isLoading = false;
        });
      } else {
        setState(() {
          teacherData = [];
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  /// --- FETCH PREVIOUS DOUBTS (CHAT HISTORY) ---
  Future<void> _fetchMyDoubts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String studentId = prefs.getString('id') ?? '';

    try {
      final response = await http.get(Uri.parse(
          "http://localhost/school_api/api.php?action=get-my-doubts&student_id=$studentId"));
      final data = json.decode(response.body);
      if (data['success']) {
        setState(() => myDoubts = data['data']);
      }
    } catch (e) {
      debugPrint("Error fetching doubts: $e");
    }
  }

  /// --- SEND DOUBT API CALL ---
  Future<void> _sendDoubt() async {
    if (_doubtController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please describe your doubt")));
      return;
    }

    setState(() => isSending = true);
    SharedPreferences prefs = await SharedPreferences.getInstance();

    try {
      final response = await http.post(
        Uri.parse("http://localhost/school_api/api.php?action=send-doubt"),
        body: {
          "student_id": prefs.getString('id'),
          "teacher_id": selectedTeacher!['teacher_id'].toString(),
          "subject": selectedTeacher!['subject'],
          "message": _doubtController.text,
        },
      );

      final data = json.decode(response.body);
      if (data['success']) {
        _doubtController.clear();
        _fetchMyDoubts(); // Refresh history
        _showSuccessDialog();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to send doubt")));
    } finally {
      setState(() => isSending = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Sent!"),
        content: const Text("Your doubt has been sent to your teacher."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("OK", style: TextStyle(color: primaryTeal)))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryTeal))
          : teacherData.isEmpty
          ? _buildNoTeacherView()
          : _buildDoubtFormView(),
    );
  }

  Widget _buildNoTeacherView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_outlined, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            const Text("No Teacher Assigned", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Contact office to assign a teacher for your class.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: primaryTeal),
              child: const Text("Go Back", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDoubtFormView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 30),
                  _buildTeacherInfoCard(),
                  const SizedBox(height: 25),
                  const Text(" Describe your doubt", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  _buildDoubtInput(),
                  const SizedBox(height: 20),
                  _buildAttachButton(),
                  const SizedBox(height: 35),
                  _buildSubmitButton(),
                  const SizedBox(height: 40),

                  // --- CHAT HISTORY SECTION ---
                  if (myDoubts.isNotEmpty) ...[
                    const Divider(thickness: 1),
                    const SizedBox(height: 10),
                    const Text("Previous Doubts & Replies", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 15),
                    _buildChatHistory(),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: primaryTeal.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
              child: Icon(Icons.quiz_rounded, color: primaryTeal, size: 28),
            ),
            const SizedBox(width: 15),
            const Text("Ask a Doubt", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        const Text("Stuck on a problem? Send it to your teacher.", style: TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildTeacherInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: primaryTeal.withOpacity(0.1), child: Icon(Icons.person, color: primaryTeal)),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(selectedTeacher!['subject'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text("Teacher: ${selectedTeacher!['teacher_name']}", style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDoubtInput() {
    return TextField(
      controller: _doubtController,
      maxLines: 5,
      decoration: InputDecoration(
        hintText: "Type your question here...",
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: primaryTeal, width: 2)),
      ),
    );
  }

  Widget _buildAttachButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: primaryTeal.withOpacity(0.3))),
      child: Column(
        children: [
          Icon(Icons.add_a_photo_outlined, color: primaryTeal, size: 30),
          const SizedBox(height: 8),
          Text("Attach a photo", style: TextStyle(color: primaryTeal, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: primaryTeal, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        onPressed: isSending ? null : _sendDoubt,
        child: isSending ? const CircularProgressIndicator(color: Colors.white) : const Text("Send to Teacher", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildChatHistory() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: myDoubts.length,
      itemBuilder: (context, index) {
        var doubt = myDoubts[index];
        return Column(
          children: [
            // Student Question
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                margin: const EdgeInsets.only(left: 50, bottom: 5),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: primaryTeal, borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), bottomLeft: Radius.circular(15), topRight: Radius.circular(15))),
                child: Text(doubt['message'], style: const TextStyle(color: Colors.white)),
              ),
            ),
            // Teacher Reply
            if (doubt['reply'] != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(right: 50, bottom: 20),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), bottomRight: Radius.circular(15), topRight: Radius.circular(15))),
                  child: Text(doubt['reply'], style: const TextStyle(color: Colors.black87)),
                ),
              )
            else
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 20, left: 5),
                  child: Text("Waiting for reply...", style: TextStyle(fontSize: 12, color: Colors.orange, fontStyle: FontStyle.italic)),
                ),
              ),
          ],
        );
      },
    );
  }
}