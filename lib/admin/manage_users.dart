import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String BASE_URL = "http://localhost/school_api";

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List users = [];
  List<String> availableClasses = ["Class 9th", "Class 10th", "Class 11th", "Class 12th"];
  List<String> availableSubjects = ["Mathematics", "Physics", "Chemistry", "Biology", "Computer Science"];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> fetchUsers() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse("$BASE_URL/api.php?action=get_all_users"));
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        List fetchedUsers = data['data'];

        Set<String> dynamicClasses = {};
        for (var u in fetchedUsers) {
          if (u['studentClass'] != null) dynamicClasses.add(u['studentClass'].toString());
        }

        setState(() {
          users = fetchedUsers;
          if (dynamicClasses.isNotEmpty) {
            availableClasses = dynamicClasses.toList()..sort();
          }
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
      setState(() => isLoading = false);
    }
  }

  // API Methods remain the same for functionality
  Future<void> _updateUser(Map<String, dynamic> userData) async {
    try {
      final response = await http.post(
        Uri.parse("$BASE_URL/api.php?action=update_user"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(userData),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        fetchUsers();
        _showSnackBar(data['message'], Colors.green);
      }
    } catch (e) { debugPrint("Update Error: $e"); }
  }

  Future<void> _adminRegisterUser(Map<String, dynamic> userData) async {
    try {
      final response = await http.post(
        Uri.parse("$BASE_URL/api.php?action=admin_add_user"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(userData),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        fetchUsers();
        _showSnackBar(data['message'], Colors.teal);
      }
    } catch (e) { debugPrint("Admin Reg Error: $e"); }
  }

  Future<void> deleteUser(String id) async {
    try {
      final response = await http.post(
        Uri.parse("$BASE_URL/api.php?action=delete_user"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"id": id}),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        fetchUsers();
        _showSnackBar("User Removed Successfully", Colors.red);
      }
    } catch (e) { debugPrint("Delete Error: $e"); }
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        elevation: 0,
        title: const Text("Manage Roles", style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 4,
          tabs: const [
            Tab(text: "Students"), // Changed from Class-wise
            Tab(text: "Teachers"), // Changed from Subject-wise
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddUserDialog(),
        backgroundColor: Colors.teal,
        label: const Text("Add New", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add, color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildGroupedList("user", "studentClass"),
              _buildGroupedList("teacher", "studentClass"), // Grouping teachers by their class
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedList(String role, String groupKey) {
    final filteredList = users.where((u) => u['userType'].toString().toLowerCase() == role.toLowerCase()).toList();
    if (filteredList.isEmpty) return const Center(child: Text("No records found."));

    Map<String, List> groupedData = {};
    for (var user in filteredList) {
      String key = (user[groupKey] == null || user[groupKey].toString().isEmpty) ? "Not Assigned" : user[groupKey].toString();
      if (!groupedData.containsKey(key)) groupedData[key] = [];
      groupedData[key]!.add(user);
    }

    final keys = groupedData.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: keys.length,
      itemBuilder: (context, index) {
        String category = keys[index];
        List categoryUsers = groupedData[category]!;
        return ExpansionTile(
          initiallyExpanded: true,
          shape: const RoundedRectangleBorder(side: BorderSide.none),
          title: Text(category, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.teal)),
          subtitle: Text("${categoryUsers.length} total"),
          children: categoryUsers.map((user) => _buildUserCard(user, role)).toList(),
        );
      },
    );
  }

  Widget _buildUserCard(Map user, String role) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: role == "teacher" ? Colors.amber[50] : Colors.teal[50],
          child: Text(user['name'][0].toUpperCase(),
              style: TextStyle(color: role == "teacher" ? Colors.orange : Colors.teal, fontWeight: FontWeight.bold)),
        ),
        title: Text(user['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user['email'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              if (role == "teacher")
                Text("Subject: ${user['subject'] ?? 'N/A'}", style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 11)),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit_rounded, color: Colors.blueAccent, size: 20), onPressed: () => _showEditUserDialog(user)),
            IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20), onPressed: () => _showDeleteDialog(user['id'].toString())),
          ],
        ),
      ),
    );
  }

  // Modal Dialogs for Add/Edit (Dynamic UI)
  void _showEditUserDialog(Map user) {
    final nameCtrl = TextEditingController(text: user['name']?.toString() ?? "");
    final emailCtrl = TextEditingController(text: user['email']?.toString() ?? "");
    final contactCtrl = TextEditingController(text: user['contact']?.toString() ?? "");
    String sClass = user['studentClass'] ?? availableClasses[0];
    String sSubject = user['subject'] ?? availableSubjects[0];

    _showFormDialog(
      title: "Edit Details",
      submitLabel: "UPDATE",
      fields: [
        _buildField(nameCtrl, "Name", Icons.person),
        _buildField(emailCtrl, "Email", Icons.email),
        _buildField(contactCtrl, "Phone", Icons.phone),
        Row(
          children: [
            Expanded(child: _buildDropdown("Class", sClass, availableClasses, (v) => sClass = v!)),
            const SizedBox(width: 10),
            Expanded(child: _buildDropdown("Subject", sSubject, availableSubjects, (v) => sSubject = v!)),
          ],
        ),
      ],
      onSubmit: () {
        _updateUser({
          "id": user['id'],
          "name": nameCtrl.text.trim(),
          "email": emailCtrl.text.trim(),
          "contact": contactCtrl.text.trim(),
          "studentClass": sClass,
          "subject": sSubject,
        });
      },
    );
  }

  void _showAddUserDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String role = "User";
    String sClass = availableClasses[0];
    String sSubject = availableSubjects[0];

    _showFormDialog(
      title: "Add New Member",
      submitLabel: "REGISTER",
      fields: [
        _buildField(nameCtrl, "Name", Icons.person_add),
        _buildField(emailCtrl, "Email", Icons.email),
        _buildField(contactCtrl, "Contact", Icons.phone),
        _buildField(passCtrl, "Password", Icons.lock),
        _buildDropdown("Role", role, ["User", "Teacher"], (v) => role = v!),
        Row(
          children: [
            Expanded(child: _buildDropdown("Class", sClass, availableClasses, (v) => sClass = v!)),
            const SizedBox(width: 10),
            Expanded(child: _buildDropdown("Subject", sSubject, availableSubjects, (v) => sSubject = v!)),
          ],
        ),
      ],
      onSubmit: () {
        _adminRegisterUser({
          "name": nameCtrl.text.trim(),
          "email": emailCtrl.text.trim(),
          "contact": contactCtrl.text.trim(),
          "password": passCtrl.text.isEmpty ? "123456" : passCtrl.text.trim(),
          "userType": role.toLowerCase(),
          "studentClass": sClass,
          "subject": sSubject,
        });
      },
    );
  }

  // UI Helpers (Form Dialog, Field, Dropdown)
  void _showFormDialog({required String title, required String submitLabel, required List<Widget> fields, required Function onSubmit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(top: 25, left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          ...fields,
          const SizedBox(height: 15),
          SizedBox(width: double.infinity, height: 45, child: ElevatedButton(
            onPressed: () { onSubmit(); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            child: Text(submitLabel, style: const TextStyle(color: Colors.white)),
          )),
        ]),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String hint, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(controller: ctrl, decoration: InputDecoration(
        labelText: hint, prefixIcon: Icon(icon, color: Colors.teal),
        filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      )),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value, items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12)))).toList(),
        onChanged: onChanged, decoration: InputDecoration(labelText: label, filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
      ),
    );
  }

  void _showDeleteDialog(String id) {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text("Confirm Delete"), content: const Text("Remove this member?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("No")),
        ElevatedButton(onPressed: () { Navigator.pop(context); deleteUser(id); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("Yes", style: TextStyle(color: Colors.white))),
      ],
    ));
  }
}