import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http; // HTTP import zaroori hai

import '../../models/attendence.dart';
import 'meeting_info.dart';

// API ka URL
const String BASE_URL = "http://localhost/school_api";

class BatchesScreen extends StatefulWidget {
  const BatchesScreen({super.key});

  @override
  State<BatchesScreen> createState() => _UserBatchesScreenState();
}

class _UserBatchesScreenState extends State<BatchesScreen> {
  int selectedDayIndex = 0;
  final Color primaryTeal = const Color(0xFF008080);

  String userSubject = "";
  String userClass = "";
  String userName = "Student";
  bool isLoading = true;
  bool isScheduleLoading = false; // Schedule ke liye alag loader
  List dbSchedule = []; // Database se aaya hua data yahan rahega

  final List<DateTime> weekDays =
  List.generate(7, (index) => DateTime.now().add(Duration(days: index)));

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        userSubject = prefs.getString('subject') ?? "";
        userClass = prefs.getString('studentClass') ?? "";
        userName = prefs.getString('name') ?? "Student";
      });

      // User data load hone ke baad aaj ka schedule fetch karein
      fetchScheduleFromDB(DateFormat('EEE').format(weekDays[selectedDayIndex]));
    }
  }

  // Database se schedule lane wala function
  Future<void> fetchScheduleFromDB(String day) async {
    if (!mounted) return;
    setState(() {
      isScheduleLoading = true;
      isLoading = false; // Main loader ko stop kar dein
    });

    try {
      final url = "$BASE_URL/api.php?action=get-schedule&day=$day&subject=${Uri.encodeComponent(userSubject)}&studentClass=${Uri.encodeComponent(userClass)}";
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            dbSchedule = (result['success'] == true) ? (result['data'] ?? []) : [];
            isScheduleLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => isScheduleLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => isScheduleLoading = false);
      debugPrint("Student Schedule Error: $e");
    }
  }

  Future<void> markAttendance(String className) async {
    final now = DateTime.now();
    String currentTime = DateFormat('hh:mm a').format(now);

    final attendance = Attendance(
      className: className,
      classTime: currentTime,
      date: now.toIso8601String(),
      status: "Present",
      studentName: userName,
    );

    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> attendanceList = prefs.getStringList('attendance') ?? [];
    attendanceList.add(jsonEncode(attendance.toMap()));
    await prefs.setStringList('attendance', attendanceList);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: isLoading
            ? Center(child: CircularProgressIndicator(color: primaryTeal))
            : Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildDaySelector(),
              const SizedBox(height: 25),
              Expanded(
                child: isScheduleLoading
                    ? Center(child: CircularProgressIndicator(color: primaryTeal))
                    : dbSchedule.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                  itemCount: dbSchedule.length,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    final cls = dbSchedule[index];
                    final channelName = "${cls["subject"]}_${cls["batch"]}".replaceAll(" ", "_");
                    return _buildClassCard(cls, channelName);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Baki UI Widgets (Header, DaySelector, Card) bilkul same rahenge ---
  // Bas DaySelector ke onTap par API call add ki hai niche:

  Widget _buildDaySelector() {
    return SizedBox(
      height: 85,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: weekDays.length,
        itemBuilder: (context, index) {
          final day = weekDays[index];
          final isSelected = index == selectedDayIndex;
          return GestureDetector(
            onTap: () {
              setState(() => selectedDayIndex = index);
              // Naya din select hone par API hit karein
              fetchScheduleFromDB(DateFormat('EEE').format(day));
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 65,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isSelected ? primaryTeal : Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(DateFormat('EEE').format(day), style: TextStyle(color: isSelected ? Colors.white70 : Colors.grey)),
                  Text(DateFormat('d').format(day), style: TextStyle(fontSize: 20, color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Header, ClassCard aur EmptyState ka purana code hi use hoga...
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("My Classes", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            Icon(Icons.school_outlined, color: primaryTeal, size: 30),
          ],
        ),
        Text("$userSubject • $userClass", style: TextStyle(color: primaryTeal, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildClassCard(dynamic cls, String channelName) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 0,
      color: Colors.grey.shade50,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: primaryTeal.withOpacity(0.1),
          child: Icon(Icons.videocam, color: primaryTeal),
        ),
        title: Text(cls["subject"] ?? "", style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("${cls["batch"]} • ${cls["time"]}"),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryTeal,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () async {
            await markAttendance("${cls["subject"]} (${cls["batch"]})");
            Navigator.push(context, MaterialPageRoute(builder: (_) => UserMeetingJoinScreen(channelName: channelName)));
          },
          child: const Text("JOIN"),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_note, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text("No classes scheduled for you today", style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}