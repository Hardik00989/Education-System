import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/attendence.dart';

const String BASE_URL = "http://localhost/school_api";

class TeacherAttendanceScreen extends StatefulWidget {
  const TeacherAttendanceScreen({super.key});

  @override
  State<TeacherAttendanceScreen> createState() => _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState extends State<TeacherAttendanceScreen> {
  List<Attendance> allRecords = [];
  List<Attendance> filteredRecords = [];
  final Color primaryTeal = const Color(0xFF008080);
  bool isLoading = true;

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
      String teacherId = prefs.getString('id') ?? "0";

      final response = await http.get(
        Uri.parse("$BASE_URL/api.php?action=get-teacher-history&teacher_id=$teacherId"),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          final List data = result['data'] ?? [];
          setState(() {
            allRecords = data.map((e) => Attendance.fromMap(e)).toList();
            _applyFilter(selectedMonth);
            isLoading = false;
          });
        } else {
          setState(() {
            allRecords = [];
            filteredRecords = [];
            isLoading = false;
          });
        }
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _applyFilter(String? month) {
    setState(() {
      selectedMonth = month!;
      if (selectedMonth == "All Months") {
        filteredRecords = allRecords;
      } else {
        filteredRecords = allRecords.where((att) {
          try {
            // Student ke join karne par jo date aayegi usse month match karna
            return DateFormat('MMMM').format(DateTime.parse(att.date)) == selectedMonth;
          } catch (e) { return false; }
        }).toList();
      }
    });
  }

  Map<String, List<Attendance>> getGroupedByDate() {
    Map<String, List<Attendance>> grouped = {};
    for (var att in filteredRecords) {
      try {
        String dateKey = DateFormat('dd MMM, yyyy').format(DateTime.parse(att.date));
        grouped.putIfAbsent(dateKey, () => []);
        grouped[dateKey]!.add(att);
      } catch (e) {
        grouped.putIfAbsent(att.date, () => []);
        grouped[att.date]!.add(att);
      }
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final groupedData = getGroupedByDate();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Daily Logs", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(onPressed: _loadAttendance, icon: Icon(Icons.refresh, color: primaryTeal))
        ],
      ),
      body: Column(
        children: [
          _buildMonthDropdown(),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: primaryTeal))
                : groupedData.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: groupedData.length,
              itemBuilder: (context, index) {
                String date = groupedData.keys.elementAt(index);
                List<Attendance> students = groupedData[date]!;
                return _buildDayCard(date, students);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthDropdown() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedMonth,
          isExpanded: true,
          items: months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
          onChanged: _applyFilter,
        ),
      ),
    );
  }

  Widget _buildDayCard(String date, List<Attendance> records) {
    // Status 'present' check karke count dikhana (case-insensitive)
    int pCount = records.where((r) => r.status.toLowerCase() == 'present').length;
    int aCount = records.length - pCount;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        title: Text(date, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("P: $pCount | A: $aCount (Total: ${records.length})"),
        leading: Icon(Icons.calendar_today, color: primaryTeal, size: 22),
        children: records.map((att) {
          bool isPresent = att.status.toLowerCase() == 'present';
          return ListTile(
            dense: true,
            leading: Icon(
              isPresent ? Icons.check_circle : Icons.cancel,
              color: isPresent ? Colors.green : Colors.red,
              size: 20,
            ),
            title: Text(att.studentName, style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text("${att.className} • ${att.classTime}"),
            trailing: Text(
              att.status.toUpperCase(),
              style: TextStyle(
                  color: isPresent ? Colors.green : Colors.red,
                  fontSize: 10,
                  fontWeight: FontWeight.bold
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text("No Record for this month", style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}