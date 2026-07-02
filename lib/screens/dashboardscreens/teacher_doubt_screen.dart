import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TeacherDoubtScreen extends StatefulWidget {
  const TeacherDoubtScreen({super.key});

  @override
  State<TeacherDoubtScreen> createState() => _TeacherDoubtScreenState();
}

class _TeacherDoubtScreenState extends State<TeacherDoubtScreen> {
  final Color primaryTeal = const Color(0xFF008080);
  List<Map<String, dynamic>> groupedDoubts = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDoubts();
  }

  Future<void> _fetchDoubts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String teacherId = prefs.getString('id') ?? '';

    try {
      final response = await http.get(Uri.parse(
          "http://localhost/school_api/api.php?action=get-teacher-doubts&teacher_id=$teacherId"));

      final data = json.decode(response.body);
      if (data['success']) {
        _processGrouping(data['data']);
      } else {
        setState(() {
          groupedDoubts = [];
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void _processGrouping(List<dynamic> rawDoubts) {
    Map<String, Map<String, dynamic>> tempMap = {};

    for (var doubt in rawDoubts) {
      String studentId = doubt['student_id'].toString();
      if (!tempMap.containsKey(studentId)) {
        tempMap[studentId] = {
          'student_id': studentId,
          'student_name': doubt['student_name'],
          'subject': doubt['subject'],
          'messages': [],
        };
      }
      tempMap[studentId]!['messages'].add(doubt);
    }

    // Isme hum saare students dikhayenge jinhone doubts puche hain
    setState(() {
      groupedDoubts = tempMap.values.toList();
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryTeal))
          : groupedDoubts.isEmpty
          ? _buildEmptyState()
          : _buildGroupedList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mark_chat_read_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("No Doubts Found", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildGroupedList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      itemCount: groupedDoubts.length,
      itemBuilder: (context, index) {
        var group = groupedDoubts[index];

        // UPDATED LOGIC: Badge sirf tab dikhega jab kam se kam ek doubt PENDING ho
        int pendingCount = group['messages'].where((m) => m['status'] != 'solved').length;
        bool hasPending = pendingCount > 0;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TeacherChatDetailScreen(
                  studentData: group,
                  primaryTeal: primaryTeal,
                  onRefresh: _fetchDoubts,
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: primaryTeal.withOpacity(0.1),
                  child: Text(group['student_name'][0].toUpperCase(),
                      style: TextStyle(color: primaryTeal, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group['student_name'],
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text("${group['subject']} • ${group['messages'].length} Messages",
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
                // Badge Logic: Agar pending hai toh dikhao, varna mat dikhao
                if (hasPending)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                    child: Text('$pendingCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class TeacherChatDetailScreen extends StatefulWidget {
  final Map<String, dynamic> studentData;
  final Color primaryTeal;
  final VoidCallback onRefresh;

  const TeacherChatDetailScreen({
    super.key,
    required this.studentData,
    required this.primaryTeal,
    required this.onRefresh,
  });

  @override
  State<TeacherChatDetailScreen> createState() => _TeacherChatDetailScreenState();
}

class _TeacherChatDetailScreenState extends State<TeacherChatDetailScreen> {
  final TextEditingController _replyController = TextEditingController();
  bool isSending = false;

  Future<void> _quickReply(String doubtId) async {
    if (_replyController.text.trim().isEmpty) return;

    setState(() => isSending = true);
    try {
      final response = await http.post(
        Uri.parse("http://localhost/school_api/api.php?action=submit-reply"),
        body: {"doubt_id": doubtId, "reply": _replyController.text.trim()},
      );

      final result = json.decode(response.body);
      if (result['success']) {
        _replyController.clear();
        widget.onRefresh(); // Refresh the list to remove the badge
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      setState(() => isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    List messages = List.from(widget.studentData['messages'].reversed);

    // Sabse purana pending doubt jiska reply dena hai
    var pendingDoubt = widget.studentData['messages'].firstWhere((m) => m['status'] != 'solved', orElse: () => null);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: widget.primaryTeal,
        title: Text(widget.studentData['student_name'], style: const TextStyle(color: Colors.white, fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                var m = messages[index];
                bool isSolved = m['status'] == 'solved';
                return _buildChatBubbles(m, isSolved);
              },
            ),
          ),

          if (pendingDoubt != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyController,
                      decoration: InputDecoration(
                        hintText: "Type solution...",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: isSending ? null : () => _quickReply(pendingDoubt['id'].toString()),
                    child: CircleAvatar(
                      backgroundColor: widget.primaryTeal,
                      child: isSending
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(15),
              width: double.infinity,
              color: Colors.grey.shade50,
              child: const Text("All doubts solved for this student ✅", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            ),
        ],
      ),
    );
  }

  Widget _buildChatBubbles(dynamic m, bool isSolved) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8, right: 40, top: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: const BorderRadius.only(topRight: Radius.circular(15), bottomLeft: Radius.circular(15), bottomRight: Radius.circular(15)),
            ),
            child: Text(m['message'], style: const TextStyle(fontSize: 15)),
          ),
        ),
        if (isSolved)
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              margin: const EdgeInsets.only(bottom: 15, left: 40),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.primaryTeal,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), bottomLeft: Radius.circular(15), bottomRight: Radius.circular(15)),
              ),
              child: Text(m['reply'], style: const TextStyle(color: Colors.white, fontSize: 15)),
            ),
          ),
      ],
    );
  }
}