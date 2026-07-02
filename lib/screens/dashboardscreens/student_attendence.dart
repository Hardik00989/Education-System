import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/attendence.dart';

// Note: Change 'localhost' to your IP address if testing on a real device
const String BASE_URL = "http://localhost/school_api";

class StudentAttendanceScreen extends StatefulWidget {
  const StudentAttendanceScreen({super.key});

  @override
  State<StudentAttendanceScreen> createState() => _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  List<Attendance> allAttendanceList = [];
  List<Attendance> filteredList = [];
  final Color primaryTeal = const Color(0xFF008080);
  bool isLoading = true;

  double attendancePercentage = 0.0;
  int presentCount = 0;
  String selectedMonth = "All Months";

  final List<String> months = [
    "All Months", "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
  ];

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String studentId = prefs.getString('id') ?? "";

      // Action name aur parameter wahi rakha hai jo API handle kar rahi hai
      final response = await http.get(
        Uri.parse("$BASE_URL/api.php?action=get-student-attendance&student_id=$studentId"),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          final List data = result['data'] ?? [];
          setState(() {
            // Model mapping with the new studentName field
            allAttendanceList = data.map((e) => Attendance.fromMap(e)).toList();
            _applyFilter(selectedMonth);
            isLoading = false;
          });
        } else {
          setState(() => isLoading = false);
        }
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Attendance Fetch Error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _applyFilter(String? month) {
    setState(() {
      selectedMonth = month!;
      if (selectedMonth == "All Months") {
        filteredList = allAttendanceList;
      } else {
        filteredList = allAttendanceList.where((att) {
          try {
            // API se aane wali date string ko parse karke month filter karna
            DateTime date = DateTime.parse(att.date);
            return DateFormat('MMMM').format(date) == selectedMonth;
          } catch (e) {
            return false;
          }
        }).toList();
      }

      int total = filteredList.length;
      presentCount = filteredList.where((e) => e.status.toLowerCase() == 'present').length;
      attendancePercentage = total > 0 ? (presentCount / total) * 100 : 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWebWide = screenWidth > 900;

    bool isLowAttendance = attendancePercentage < 75 && filteredList.isNotEmpty;
    Color progressBarColor = isLowAttendance ? Colors.orangeAccent : Colors.white;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Padding(
              padding: EdgeInsets.fromLTRB(isWebWide ? 40 : 20, 25, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Attendance History",
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Showing ${filteredList.length} records",
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: _loadAttendance,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: primaryTeal.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(Icons.refresh, color: primaryTeal),
                    ),
                  ),
                ],
              ),
            ),

            // Progress Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              margin: EdgeInsets.symmetric(horizontal: isWebWide ? 40 : 16, vertical: 10),
              decoration: BoxDecoration(
                color: primaryTeal,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [BoxShadow(color: primaryTeal.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        selectedMonth == "All Months" ? "Overall Progress" : "$selectedMonth Stats",
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      Text(
                        "${attendancePercentage.toStringAsFixed(1)}%",
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: attendancePercentage / 100,
                      backgroundColor: Colors.white24,
                      color: progressBarColor,
                      minHeight: 8,
                    ),
                  ),
                  if (isLowAttendance)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        "Warning: Attendance below 75%",
                        style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),

            // Month Filter Dropdown
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isWebWide ? 40 : 16, vertical: 5),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedMonth,
                    isExpanded: true,
                    icon: Icon(Icons.filter_list, color: primaryTeal),
                    items: months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: _applyFilter,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Main List
            Expanded(
              child: isLoading
                  ? Center(child: CircularProgressIndicator(color: primaryTeal))
                  : filteredList.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                onRefresh: _loadAttendance,
                color: primaryTeal,
                child: ListView.builder(
                  itemCount: filteredList.length,
                  padding: EdgeInsets.symmetric(horizontal: isWebWide ? 40 : 16, vertical: 10),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    final att = filteredList[index];
                    String dateStr;
                    try {
                      dateStr = DateFormat('dd MMM, yyyy').format(DateTime.parse(att.date));
                    } catch (e) {
                      dateStr = att.date;
                    }

                    bool isPresent = att.status.toLowerCase() == 'present';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 18),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8))],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (isPresent ? Colors.green : Colors.red).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              isPresent ? Icons.verified_user_rounded : Icons.cancel_rounded,
                              color: isPresent ? Colors.green : Colors.red,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(att.className, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87)),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 4,
                                  children: [
                                    _buildInfoIcon(Icons.calendar_month_outlined, dateStr),
                                    _buildInfoIcon(Icons.access_time_rounded, att.classTime),
                                    // Chhota sa student name niche dikhane ke liye
                                    _buildInfoIcon(Icons.person_outline, att.studentName),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isPresent ? Colors.green : Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              att.status.toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoIcon(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy_outlined, size: 80, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text(
            "No records found for $selectedMonth",
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}