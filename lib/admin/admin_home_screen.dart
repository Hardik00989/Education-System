import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:new_task/admin/allfeedbacks.dart';
import 'admin_add_questions.dart';
import 'admin_study_material.dart';
import 'manage_users.dart';
// TODO: Apne folder structure ke hisaab se isse import karein
// import 'admin_add_study_material.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final String baseUrl = "http://localhost/school_api/api.php";

  Map<String, dynamic> stats = {
    "total_students": "0",
    "total_teachers": "0",
    "total_materials": "0",
    "pending_doubts": "0"
  };
  bool isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    fetchStats();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      fetchStats();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchStats() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl?action=get_admin_stats"));
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        if (mounted) {
          setState(() {
            stats = data['data'];
            isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Stats Error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Admin Panel", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.teal,
        elevation: 0,
        actions: [
          IconButton(onPressed: fetchStats, icon: const Icon(Icons.refresh, color: Colors.white)),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Quick Overview", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),

                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: isTablet ? 4 : 2,
                      childAspectRatio: isTablet ? 1.2 : 1.4,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      children: [
                        _buildStatCard("Students", stats['total_students'].toString(), Icons.school, Colors.blue),
                        _buildStatCard("Teachers", stats['total_teachers'].toString(), Icons.person, Colors.orange),
                        _buildStatCard("Materials", stats['total_materials'].toString(), Icons.book, Colors.purple),
                        _buildStatCard("Doubts", stats['pending_doubts'].toString(), Icons.help_outline, Colors.red),
                      ],
                    ),

                    const SizedBox(height: 30),
                    const Text("Control Center", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),

                    _buildMenuTile("Manage Users & Roles", "Add, Edit or Remove staff and students", Icons.people_alt, Colors.teal, () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageUsersScreen()));
                    }),

                    _buildMenuTile("Practice Questions", "Post and manage SSC, Banking, and GS questions", Icons.quiz_rounded, Colors.indigo, () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminAddQuestion()));
                    }),

                    // Naya Card: Study Material Management
                    _buildMenuTile("Study Material Management", "Upload notes, PDFs, and subjects for students", Icons.library_books_rounded, Colors.deepPurple, () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminAddStudyMaterial()));
                    }),

                    _buildMenuTile("Student Feedbacks", "Read what students say about teachers", Icons.star_rate, Colors.amber[800]!, () {
                      Navigator.push(context, MaterialPageRoute(builder: (context)=> const AllfeedbacksScreen()));
                    }),

                    _buildMenuTile("App Settings", "Configure notifications and system", Icons.settings, Colors.grey[700]!, () {}),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, spreadRadius: 2)]
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(count, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color, size: 22)
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, size: 20),
      ),
    );
  }
}