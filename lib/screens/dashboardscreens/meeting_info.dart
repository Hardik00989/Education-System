import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../video_call.dart';

// Login screen waali same BASE_URL use karein
const String BASE_URL = "http://localhost/school_api";

class UserMeetingJoinScreen extends StatefulWidget {
  final String channelName;

  const UserMeetingJoinScreen({
    super.key,
    required this.channelName,
  });

  @override
  State<UserMeetingJoinScreen> createState() => _UserMeetingJoinScreenState();
}

class _UserMeetingJoinScreenState extends State<UserMeetingJoinScreen> with SingleTickerProviderStateMixin {
  final TextEditingController meetingIdController = TextEditingController();
  final TextEditingController nameController = TextEditingController();

  bool rememberName = false;
  final Color primaryTeal = const Color(0xFF008080);
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    meetingIdController.text = widget.channelName;
    _loadSavedName(); // Pehle se saved name load karne ke liye

    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 5))
      ..repeat(reverse: true);
  }

  // UI Load hote hi agar 'Remember me' kiya tha toh name dikhana
  Future<void> _loadSavedName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      nameController.text = prefs.getString('name') ?? "";
      rememberName = nameController.text.isNotEmpty;
    });
  }

  // Naya Logic: Background mein attendance mark karna
  Future<void> _markAttendanceSilently() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? studentId = prefs.getString('id');

      if (studentId != null) {
        final url = Uri.parse("$BASE_URL/api.php?action=mark-join-attendance");
        await http.post(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "student_id": studentId,
            "meeting_id": widget.channelName,
          }),
        );
        debugPrint("Attendance marked for Student ID: $studentId");
      }
    } catch (e) {
      debugPrint("Attendance Error: $e");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    meetingIdController.dispose();
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.lerp(const Color(0xFF6DD5FA), primaryTeal, _controller.value)!,
                  Color.lerp(primaryTeal, const Color(0xFF2980B9), _controller.value)!
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 10,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          constraints: const BoxConstraints(maxWidth: 450),
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 25,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 35,
                                backgroundColor: primaryTeal.withOpacity(0.1),
                                child: Icon(Icons.school_rounded, color: primaryTeal, size: 35),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                "Join Your Class",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const Text(
                                "Enter your name to attend the session",
                                style: TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                              const SizedBox(height: 30),
                              _buildLabel("Meeting Passcode"),
                              _buildTextField(
                                controller: meetingIdController,
                                readOnly: true,
                                icon: Icons.vpn_key_outlined,
                              ),
                              const SizedBox(height: 20),
                              _buildLabel("Your Full Name"),
                              _buildTextField(
                                controller: nameController,
                                readOnly: false,
                                icon: Icons.person_outline,
                                hint: "e.g. Hardik Sharma",
                              ),
                              const SizedBox(height: 10),
                              Theme(
                                data: Theme.of(context).copyWith(unselectedWidgetColor: Colors.grey),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: rememberName,
                                      activeColor: primaryTeal,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                      onChanged: (value) => setState(() => rememberName = value!),
                                    ),
                                    const Text(
                                      "Remember my name",
                                      style: TextStyle(color: Colors.black54, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 30),
                              SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryTeal,
                                    elevation: 4,
                                    shadowColor: primaryTeal.withOpacity(0.4),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                  ),
                                  onPressed: () async {
                                    final String userName = nameController.text.trim();
                                    if (userName.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Please enter your name")),
                                      );
                                      return;
                                    }

                                    // OLD LOGIC PRESERVED: Save name if checkbox is ticked
                                    if (rememberName) {
                                      SharedPreferences prefs = await SharedPreferences.getInstance();
                                      await prefs.setString('name', userName);
                                    }

                                    // NEW LOGIC: Mark Attendance in Background
                                    _markAttendanceSilently();

                                    // OLD LOGIC PRESERVED: Navigate to VideoCall
                                    if (!mounted) return;
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => VideoCallScreen(
                                          appId: 1275329257,
                                          appSign: "2645c9b083fa3e0495501a5807e4a0f94b07a0da50f9c5e79776473417f9e033",
                                          channelName: meetingIdController.text,
                                          userName: userName,
                                          userId: "std_${DateTime.now().millisecondsSinceEpoch}",
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    "Join Now",
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                "By clicking Join, you agree to our Terms",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54, fontSize: 14)),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required bool readOnly, required IconData icon, String? hint}) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      style: TextStyle(color: readOnly ? primaryTeal : Colors.black87, fontWeight: readOnly ? FontWeight.bold : FontWeight.normal),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
        prefixIcon: Icon(icon, color: primaryTeal),
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: primaryTeal, width: 2)),
      ),
    );
  }
}