import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../permissions/audio_video_permission.dart';
import '../../video_call.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  TextEditingController meetingController = TextEditingController();
  TextEditingController nameController = TextEditingController();
  bool rememberName = false;
  final Color brandTeal = const Color(0xFF008080);

  List dynamicTabsData = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchPracticeData();
  }

  Future<void> fetchPracticeData() async {
    try {
      final response = await http.get(
        Uri.parse("http://localhost/school_api/api.php?action=get-practice-tabs"),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            dynamicTabsData = data['data'];
            isLoading = false;
          });
          return;
        }
      }
      setState(() => isLoading = false);
    } catch (e) {
      debugPrint("API Error: $e");
      setState(() => isLoading = false);
    }
  }

  Widget _responsiveBody(Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: child,
      ),
    );
  }

  // UI same rakha hai, bas numbering display add ki hai
  Widget _questionTile(String q, String a, int index) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Automatic Numbering (Q1, Q2...) yahan add ki gayi hai
          Text("Q${index + 1}. $q",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.check_circle_outline, size: 18, color: Colors.teal),
              const SizedBox(width: 8),
              Expanded(
                child: Text("Answer: $a",
                    style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.teal)));
    }

    int totalTabs = 1 + dynamicTabsData.length + 4;

    return DefaultTabController(
      length: totalTabs,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7F9),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          toolbarHeight: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60.0),
            child: TabBar(
              tabAlignment: TabAlignment.start,
              isScrollable: true,
              indicatorColor: Colors.red,
              indicatorWeight: 3,
              labelPadding: const EdgeInsets.symmetric(horizontal: 20),
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: [
                Tab(
                    height: 55,
                    child: Row(
                      children: [
                        const Text("Live Class"),
                        const SizedBox(width: 6),
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                      ],
                    )
                ),
                ...dynamicTabsData.map((cat) => Tab(height: 55, text: cat['category_name'].toString())).toList(),
                const Tab(height: 55, text: "Offline Test"),
                const Tab(height: 55, text: "Offline Batch"),
                const Tab(height: 55, text: "Sure 60 Gurukul"),
                const Tab(height: 55, text: "Student Helpdesk"),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            // --- TAB 1: LIVE CLASS ---
            _responsiveBody(SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF008080), Color(0xFF004D4D)]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(5)),
                              child: const Text("LIVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                            const SizedBox(width: 10),
                            const Text("1.2k Students Watching", style: TextStyle(color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 15),
                        const Text("Maths Special: Percentage & Profit Loss", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        const Text("By: Sahil Sir", style: TextStyle(color: Colors.white70, fontSize: 16)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)],
                    ),
                    child: Column(
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.security, color: Colors.teal),
                            SizedBox(width: 10),
                            Text("Secure Classroom Access", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Divider(height: 30),
                        TextField(
                          controller: meetingController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.meeting_room_outlined),
                            labelText: "Batch / Meeting Passcode",
                            hintText: "Enter your class code",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.badge_outlined),
                            labelText: "Student Name",
                            hintText: "Enter your full name",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            Switch(
                                activeColor: brandTeal,
                                value: rememberName,
                                onChanged: (value) => setState(() => rememberName = value)
                            ),
                            const Text("Save info for next class", style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 55, width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              bool granted = await requestPermisson();
                              if (granted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => VideoCallScreen(
                                      appId: 1275329257,
                                      appSign: "2645c9b083fa3e0495501a5807e4a0f94b07a0da50f9c5e79776473417f9e033",
                                      channelName: meetingController.text.trim(),
                                      userName: nameController.text.trim(),
                                      userId: "student_${DateTime.now().millisecondsSinceEpoch}",
                                    ),
                                  ),
                                );
                              }
                            },
                            child: const Text("ENTER LIVE CLASS", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),

            // --- DYNAMIC QUESTION TABS ---
            ...dynamicTabsData.map((category) {
              List questions = category['questions'] ?? [];
              return _responsiveBody(ListView(
                padding: const EdgeInsets.symmetric(vertical: 20),
                children: [
                  Center(child: Text("${category['category_name']} Practice Questions (${questions.length})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                  const SizedBox(height: 15),
                  // .asMap().entries.map logic add ki gayi hai index ke liye
                  ...questions.asMap().entries.map((entry) {
                    int idx = entry.key;
                    var qData = entry.value;
                    return _questionTile(qData['q'].toString(), qData['a'].toString(), idx);
                  }).toList(),
                ],
              ));
            }).toList(),

            for (int i = 0; i < 4; i++) const Center(child: Text("Section Content Coming Soon")),
          ],
        ),
      ),
    );
  }
}