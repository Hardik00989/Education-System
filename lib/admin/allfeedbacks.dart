import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AllfeedbacksScreen extends StatefulWidget {
  const AllfeedbacksScreen({super.key});

  @override
  State<AllfeedbacksScreen> createState() => _AllfeedbacksScreenState();
}

class _AllfeedbacksScreenState extends State<AllfeedbacksScreen> {
  final String apiUrl = "http://localhost/school_api/api.php?action=get_all_feedbacks";
  List allFeedbacks = [];
  List teacherStats = [];
  List<String> dynamicClassList = ["All"];
  String selectedClass = "All";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchFeedbacks();
  }

  Future<void> fetchFeedbacks() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse(apiUrl));
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        List fetchedData = data['data'];
        Set<String> uniqueClasses = {"All"};
        for (var f in fetchedData) {
          if (f['student_class'] != null && f['student_class'].toString().isNotEmpty) {
            uniqueClasses.add(f['student_class'].toString());
          }
        }
        setState(() {
          allFeedbacks = fetchedData;
          dynamicClassList = uniqueClasses.toList()..sort();
          _processTeacherPerformance();
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
      setState(() => isLoading = false);
    }
  }

  void _processTeacherPerformance() {
    Map<String, Map<String, dynamic>> teacherMap = {};
    List dataToProcess = selectedClass == "All"
        ? allFeedbacks
        : allFeedbacks.where((f) => f['student_class'].toString() == selectedClass).toList();

    for (var f in dataToProcess) {
      String tId = f['teacher_id'].toString();
      double currentRating = double.tryParse(f['rating']?.toString() ?? '0') ?? 0;

      if (!teacherMap.containsKey(tId)) {
        teacherMap[tId] = {
          'teacher_id': tId,
          'teacher_name': f['teacher_name'],
          'student_class': f['student_class'],
          'total_responses': 1,
          'sum_rating': currentRating,
          'all_teacher_feedbacks': [f],
        };
      } else {
        teacherMap[tId]!['total_responses'] += 1;
        teacherMap[tId]!['sum_rating'] += currentRating;
        teacherMap[tId]!['all_teacher_feedbacks'].add(f);
      }
    }
    setState(() => teacherStats = teacherMap.values.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        elevation: 0,
        title: const Text("Teacher Performance", style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.teal,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800), // Dropdown width limit for Web
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedClass,
                  isExpanded: true,
                  icon: const Icon(Icons.tune_rounded, color: Colors.teal),
                  style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
                  items: dynamicClassList.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                  onChanged: (v) {
                    setState(() {
                      selectedClass = v!;
                      _processTeacherPerformance();
                    });
                  },
                ),
              ),
            ),
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800), // MAGIC: Sabhi screen par sahi dikhega
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: teacherStats.length,
            itemBuilder: (context, index) {
              final t = teacherStats[index];
              double avg = t['sum_rating'] / t['total_responses'];

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))
                    ],
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TeacherDetailsScreen(
                            teacherName: t['teacher_name'],
                            feedbacks: t['all_teacher_feedbacks'],
                          ),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
                                child: const Icon(Icons.person_outline_rounded, color: Colors.teal, size: 30),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(t['teacher_name'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF2D3142))),
                                    const SizedBox(height: 4),
                                    Text("Class: ${t['student_class']}", style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                              if (avg >= 4.5)
                                const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 35),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.03),
                            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildBadge("Avg: ${avg.toStringAsFixed(1)} ★", avg >= 4 ? Colors.green : Colors.orange),
                              _buildBadge("${t['total_responses']} Students", Colors.blueGrey),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.teal),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}

class TeacherDetailsScreen extends StatelessWidget {
  final String teacherName;
  final List feedbacks;

  const TeacherDetailsScreen({super.key, required this.teacherName, required this.feedbacks});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        title: Text(teacherName, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: feedbacks.length,
            itemBuilder: (context, index) {
              final f = feedbacks[index];
              int r = int.tryParse(f['rating']?.toString() ?? '1') ?? 1;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(f['student_name'] ?? "Anonymous", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                        Row(
                          children: List.generate(5, (i) => Icon(
                            i < r ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: Colors.amber, size: 16,
                          )),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      f['feedback_text'] ?? "No comment",
                      style: const TextStyle(color: Color(0xFF4F5E7B), height: 1.4, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        f['created_at'].toString().split(' ')[0],
                        style: TextStyle(fontSize: 11, color: Colors.grey[400], fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}