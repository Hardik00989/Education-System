import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:new_task/screens/dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Use 10.0.2.2 for Android Emulator, or your local IP for real devices
const String BASE_URL = "http://localhost/school_api";

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  bool isdisplay = false;
  bool isconfirm = false;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController contactController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  String userType = "User";
  String qualification = "Graduated";
  String selectedClass = "Class 9th";
  String selectedCountry = "India";
  String selectedSubject = "Mathematics";

  final List<String> countries = ["USA", "UK", "Canada", "India", "Australia", "Germany"];
  final List<String> subjects = ["Mathematics", "Physics", "Chemistry", "Biology", "Computer Science"];
  final List<String> classes = ["Class 9th", "Class 10th", "Class 11th", "Class 12th"];

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    nameController.dispose();
    contactController.dispose();
    addressController.dispose();
    super.dispose();
  }

  Future<void> register() async {
    if (emailController.text.isEmpty || nameController.text.isEmpty || passwordController.text.isEmpty || contactController.text.isEmpty || addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All fields are required")));
      return;
    }

    if (passwordController.text != confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passwords do not match")));
      return;
    }

    final url = Uri.parse("$BASE_URL/api.php?action=register");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "name": nameController.text.trim(),
          "email": emailController.text.trim(),
          "password": passwordController.text.trim(),
          "contact": contactController.text.trim(),
          "address": addressController.text.trim(),
          "userType": userType.toLowerCase(),
          "country": selectedCountry,
          "subject": selectedSubject,
          "qualification": userType == "Teacher" ? qualification : null,
          "studentClass": selectedClass,
        }),
      );

      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        SharedPreferences prefs = await SharedPreferences.getInstance();

        // --- THE REQUIRED CHANGE: SAVE TEACHER ID ---
        // Ensuring the ID from the database is stored for assignments
        await prefs.setString('id', data['id']?.toString() ?? "");

        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('token', data['token'] ?? "");
        await prefs.setString('userType', userType.toLowerCase());
        await prefs.setString('name', nameController.text.trim());
        await prefs.setString('email', emailController.text.trim());
        await prefs.setString('subject', selectedSubject);
        await prefs.setString('country', selectedCountry);
        await prefs.setString('studentClass', selectedClass);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Registration Successful!")));

        Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => DashboardScreen(userType: userType.toLowerCase()))
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? "Error")));
      }
    } catch (e) {
      debugPrint("Register Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Server error: Check if XAMPP is running")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cardWidth = size.width < 600 ? size.width * 0.9 : size.width * 0.4;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Container(
            width: double.infinity, height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.lerp(const Color(0xFF6DD5FA), const Color(0xFF2980B9), _controller.value)!,
                  Color.lerp(const Color(0xFF2980B9), const Color(0xFF6DD5FA), _controller.value)!
                ],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Container(
                width: cardWidth,
                constraints: BoxConstraints(maxHeight: size.height * 0.85),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.98),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 20)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      children: [
                        const Icon(Icons.person_add_alt_1, size: 70, color: Colors.teal),
                        const SizedBox(height: 10),
                        const Text("Create Account", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 25),
                        _buildTextField(nameController, "Full Name", Icons.person_outline),
                        _buildTextField(emailController, "Email Address", Icons.email_outlined),
                        _buildTextField(contactController, "Contact Number", Icons.phone_outlined, keyboard: TextInputType.phone),
                        _buildTextField(addressController, "Address", Icons.location_on_outlined),
                        _buildPasswordField(passwordController, "Password", isdisplay, () => setState(() => isdisplay = !isdisplay)),
                        _buildPasswordField(confirmController, "Confirm Password", isconfirm, () => setState(() => isconfirm = !isconfirm)),
                        const Divider(),
                        _buildDropdownLabel("Select Country:"),
                        _buildDropdownContainer(
                          DropdownButton<String>(
                            value: selectedCountry,
                            isExpanded: true,
                            underline: const SizedBox(),
                            items: countries.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (value) => setState(() => selectedCountry = value!),
                          ),
                        ),
                        const SizedBox(height: 15),
                        _buildDropdownLabel("Register as:"),
                        _buildDropdownContainer(
                          DropdownButton<String>(
                            value: userType,
                            isExpanded: true,
                            underline: const SizedBox(),
                            items: const [
                              DropdownMenuItem(value: "User", child: Text("Student")),
                              DropdownMenuItem(value: "Teacher", child: Text("Teacher")),
                            ],
                            onChanged: (value) => setState(() {
                              userType = value!;
                            }),
                          ),
                        ),
                        const SizedBox(height: 15),
                        _buildDropdownLabel(userType == "Teacher" ? "Which class you teach?" : "Select Your Class:"),
                        _buildDropdownContainer(
                          DropdownButton<String>(
                            value: selectedClass,
                            isExpanded: true,
                            underline: const SizedBox(),
                            items: classes.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                            onChanged: (value) => setState(() => selectedClass = value!),
                          ),
                        ),
                        const SizedBox(height: 15),
                        _buildDropdownLabel(userType == "Teacher" ? "Your Specialization:" : "Interested Subject:"),
                        _buildDropdownContainer(
                          DropdownButton<String>(
                            value: selectedSubject,
                            isExpanded: true,
                            underline: const SizedBox(),
                            items: subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                            onChanged: (value) => setState(() => selectedSubject = value!),
                          ),
                        ),
                        if (userType == "Teacher") ...[
                          const SizedBox(height: 15),
                          _buildDropdownLabel("Highest Qualification:"),
                          _buildDropdownContainer(
                            DropdownButton<String>(
                              value: qualification,
                              isExpanded: true,
                              underline: const SizedBox(),
                              items: const ["Graduated", "Post Graduated", "Doctorate"]
                                  .map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                              onChanged: (value) => setState(() => qualification = value!),
                            ),
                          ),
                        ],
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity, height: 50,
                          child: ElevatedButton(
                            onPressed: register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text("SIGN UP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Already have an account? "),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Text("Login", style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDropdownLabel(String label) => Align(alignment: Alignment.centerLeft, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)));
  Widget _buildDropdownContainer(Widget child) => Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)), child: child);
  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {TextInputType keyboard = TextInputType.text}) => Padding(padding: const EdgeInsets.only(bottom: 15), child: TextField(controller: controller, keyboardType: keyboard, decoration: InputDecoration(hintText: hint, filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), prefixIcon: Icon(icon, color: Colors.teal))));
  Widget _buildPasswordField(TextEditingController controller, String hint, bool visible, VoidCallback toggle) => Padding(padding: const EdgeInsets.only(bottom: 15), child: TextField(controller: controller, obscureText: !visible, decoration: InputDecoration(hintText: hint, filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), prefixIcon: const Icon(Icons.lock_outline, color: Colors.teal), suffixIcon: IconButton(icon: Icon(visible ? Icons.visibility : Icons.visibility_off), onPressed: toggle))));
}