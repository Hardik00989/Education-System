import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String BASE_URL = "http://localhost/school_api";

class AdminhelpScreen extends StatefulWidget {
  const AdminhelpScreen({super.key});

  @override
  State<AdminhelpScreen> createState() => _AdminhelpScreenState();
}

class _AdminhelpScreenState extends State<AdminhelpScreen> {
  List schedules = [];
  List teachers = [];
  bool isLoading = true;

  // --- DYNAMIC LISTS (Ab ye fetch se populate honge) ---
  List<String> availableClasses = [];
  List<String> availableSubjects = [];

  @override
  void initState() {
    super.initState();
    fetchInitialData();
  }

  Future<void> fetchInitialData() async {
    setState(() => isLoading = true);
    try {
      final resSched = await http.get(Uri.parse("$BASE_URL/api.php?action=get_all_schedules"));
      final resUsers = await http.get(Uri.parse("$BASE_URL/api.php?action=get_all_users"));

      final dataSched = jsonDecode(resSched.body);
      final dataUsers = jsonDecode(resUsers.body);

      if (dataUsers['success']) {
        List allUsers = dataUsers['data'];

        // 1. Filter Teachers
        teachers = allUsers.where((u) => u['userType'].toString().toLowerCase() == 'teacher').toList();

        // 2. Extract Unique Classes and Subjects
        Set<String> classSet = {};
        Set<String> subjectSet = {};

        for (var user in allUsers) {
          if (user['studentClass'] != null && user['studentClass'].toString().isNotEmpty) {
            classSet.add(user['studentClass'].toString());
          }
          if (user['subject'] != null && user['subject'].toString().isNotEmpty) {
            subjectSet.add(user['subject'].toString());
          }
        }

        setState(() {
          // Sets ko list mein convert karke sort karna
          availableClasses = classSet.toList()..sort();
          availableSubjects = subjectSet.toList()..sort();

          // Fallback agar database khali ho
          if (availableClasses.isEmpty) availableClasses = ["General"];
          if (availableSubjects.isEmpty) availableSubjects = ["General"];

          if (dataSched['success']) schedules = dataSched['data'];
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _addSchedule(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse("$BASE_URL/api.php?action=add_schedule"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );
      if (jsonDecode(res.body)['success']) {
        fetchInitialData();
        _showSnackBar("Schedule Added Successfully!", Colors.teal);
      }
    } catch (e) {
      debugPrint("Add Error: $e");
    }
  }

  Future<void> _deleteSchedule(String id) async {
    try {
      final res = await http.post(
        Uri.parse("$BASE_URL/api.php?action=delete_schedule"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"id": id}),
      );
      if (jsonDecode(res.body)['success']) {
        fetchInitialData();
        _showSnackBar("Schedule Removed", Colors.redAccent);
      }
    } catch (e) {
      debugPrint("Delete Error: $e");
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        title: const Text("Manage Schedules", style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddScheduleDialog(),
        backgroundColor: Colors.teal,
        label: const Text("New Class", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add_task_rounded, color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: schedules.isEmpty
              ? const Center(child: Text("No schedules found. Create one!"))
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: schedules.length,
            itemBuilder: (context, index) {
              final s = schedules[index];
              return _buildScheduleCard(s);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleCard(Map s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 70,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
              child: Column(
                children: [
                  Text(s['day'], style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.teal, fontSize: 16)),
                  const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.teal),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s['subject'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                  Text("Batch: ${s['batch']}", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(s['teacher_name'] ?? 'Unassigned', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(s['time'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 12)),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  onPressed: () => _confirmDelete(s['id'].toString()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddScheduleDialog() {
    // Initial values based on dynamic data
    String selectedDay = "Mon";
    String selectedSubject = availableSubjects.isNotEmpty ? availableSubjects.first : "";
    String selectedBatch = availableClasses.isNotEmpty ? availableClasses.first : "";
    String? selectedTeacherId;
    final timeCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(top: 25, left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("New Schedule Slot", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal)),
              const SizedBox(height: 20),
              _buildDropdown("Select Day", selectedDay, ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], (v) => setModalState(() => selectedDay = v!)),

              TextField(
                controller: timeCtrl,
                readOnly: true,
                decoration: _fieldStyle("Pick Time", Icons.access_time_rounded),
                onTap: () async {
                  TimeOfDay? picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                  if (picked != null) setModalState(() => timeCtrl.text = picked.format(context));
                },
              ),
              const SizedBox(height: 12),

              _buildDropdown("Select Subject", selectedSubject, availableSubjects, (v) => setModalState(() => selectedSubject = v!)),
              const SizedBox(height: 12),

              _buildDropdown("Select Batch/Class", selectedBatch, availableClasses, (v) => setModalState(() => selectedBatch = v!)),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: selectedTeacherId,
                items: teachers.map((t) => DropdownMenuItem(value: t['id'].toString(), child: Text(t['name']))).toList(),
                onChanged: (v) => setModalState(() => selectedTeacherId = v),
                decoration: _fieldStyle("Assign Teacher", Icons.person_search_rounded),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (timeCtrl.text.isEmpty) {
                      _showSnackBar("Please select a time", Colors.orange);
                      return;
                    }
                    _addSchedule({
                      "day": selectedDay,
                      "time": timeCtrl.text,
                      "subject": selectedSubject,
                      "batch": selectedBatch,
                      "teacher_id": selectedTeacherId,
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  child: const Text("CREATE SCHEDULE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldStyle(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: Colors.teal),
    filled: true,
    fillColor: Colors.grey[100],
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
  );

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: items.contains(value) ? value : (items.isNotEmpty ? items.first : null),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
        decoration: _fieldStyle(label, Icons.list_rounded),
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete?"),
        content: const Text("Remove this schedule?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("No")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteSchedule(id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Yes", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}