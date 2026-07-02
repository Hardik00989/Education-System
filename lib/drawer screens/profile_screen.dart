import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';

import '../screens/Login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final Color primaryTeal = const Color(0xFF008080);

  // --- API CONFIGURATION ---
  final String baseUrl = "http://localhost/school_api/";
  final String imageBaseUrl = "http://localhost/school_api/uploads/profiles/";

  String userName = "Loading...";
  String userEmail = "Loading...";
  String userContact = "";
  String userAddress = "";
  String userQualification = "";
  String userRole = "user";
  String? profilePicName;
  String firstLetter = "U";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        userName = prefs.getString('name') ?? "User Name";
        userEmail = prefs.getString('email') ?? "No Email Found";
        userContact = prefs.getString('contact') ?? "";
        userAddress = prefs.getString('address') ?? "";

        userRole = (prefs.getString('userType') ?? "user").toLowerCase();
        userQualification = (userRole == "teacher")
            ? (prefs.getString('qualification') ?? "")
            : "";

        profilePicName = prefs.getString('profile_pic');

        if (userName.isNotEmpty && userName != "Loading...") {
          firstLetter = userName[0].toUpperCase();
        }
        isLoading = false;
      });
    }
  }

  // --- CHANGE PASSWORD ---
  void _showChangePasswordDialog() {
    final TextEditingController oldPassController = TextEditingController();
    final TextEditingController newPassController = TextEditingController();
    final TextEditingController confirmPassController = TextEditingController();
    String? oldPassError;
    bool isObscure = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text("Change Password", style: TextStyle(color: primaryTeal, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: oldPassController,
                      obscureText: isObscure,
                      cursorColor: primaryTeal,
                      onChanged: (val) { if (oldPassError != null) setDialogState(() => oldPassError = null); },
                      decoration: _inputDecoration("Current Password", Icons.lock_outline).copyWith(
                        errorText: oldPassError,
                        suffixIcon: IconButton(
                          icon: Icon(isObscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey, size: 20),
                          onPressed: () => setDialogState(() => isObscure = !isObscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildPasswordField(newPassController, "New Password", isObscure, () => setDialogState(() => isObscure = !isObscure)),
                    const SizedBox(height: 15),
                    _buildPasswordField(confirmPassController, "Confirm New Password", isObscure, () => setDialogState(() => isObscure = !isObscure)),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryTeal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                  onPressed: () async {
                    if (oldPassController.text.isEmpty || newPassController.text.isEmpty) { _showSnackBar("Please fill all fields"); return; }
                    if (newPassController.text != confirmPassController.text) { _showSnackBar("New passwords do not match!"); return; }

                    final result = await _changePassword(oldPassController.text, newPassController.text);
                    if (result['success'] == true) {
                      Navigator.pop(context);
                      _showSnackBar("Password updated! Logging out...");
                      await Future.delayed(const Duration(seconds: 2));
                      if (mounted) _handleLogout();
                    } else {
                      setDialogState(() { oldPassError = result['message'] ?? "Incorrect password"; });
                    }
                  },
                  child: const Text("Update Password", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- EDIT PROFILE DIALOG ---
  void _showEditDialog() {
    TextEditingController nameController = TextEditingController(text: userName);
    TextEditingController contactController = TextEditingController(text: userContact);
    TextEditingController addressController = TextEditingController(text: userAddress);

    String selectedQual = (userQualification.isEmpty) ? "Graduated" : userQualification;
    final List<String> qualOptions = ["Graduated", "Post Graduated", "Doctorate"];
    bool hasChanged = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void checkForChanges() {
              bool currentChangeStatus = nameController.text != userName ||
                  contactController.text != userContact ||
                  addressController.text != userAddress ||
                  (userRole == "teacher" && selectedQual != userQualification);
              if (currentChangeStatus != hasChanged) setDialogState(() => hasChanged = currentChangeStatus);
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text("Update Profile", style: TextStyle(color: primaryTeal, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDialogField(nameController, "Full Name", Icons.person_outline, (val) => checkForChanges()),
                    const SizedBox(height: 15),
                    _buildDialogField(contactController, "Contact No", Icons.phone_outlined, (val) => checkForChanges()),
                    const SizedBox(height: 15),
                    _buildDialogField(addressController, "Address", Icons.location_on_outlined, (val) => checkForChanges()),
                    if (userRole == "teacher") ...[
                      const SizedBox(height: 15),
                      DropdownButtonFormField<String>(
                        value: qualOptions.contains(selectedQual) ? selectedQual : qualOptions[0],
                        dropdownColor: Colors.white,
                        decoration: _inputDecoration("Qualification", Icons.school_outlined),
                        items: qualOptions.map((val) => DropdownMenuItem(value: val, child: Text(val, style: const TextStyle(fontSize: 14)))).toList(),
                        onChanged: (newValue) {
                          setDialogState(() { selectedQual = newValue!; checkForChanges(); });
                        },
                      ),
                    ],
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasChanged ? primaryTeal : Colors.grey.shade400,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: hasChanged ? () {
                    Navigator.pop(context);
                    _updateProfile(nameController.text, contactController.text, addressController.text, (userRole == "teacher") ? selectedQual : "");
                  } : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Text(hasChanged ? "Update Changes" : "Save Changes", style: const TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- HELPER UI ---
  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: primaryTeal, size: 20),
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
      filled: true,
      fillColor: Colors.grey.shade50,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryTeal, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 1.2)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 1.8)),
      errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
    );
  }

  Widget _buildDialogField(TextEditingController controller, String label, IconData icon, Function(String) onChanged) {
    return TextField(controller: controller, onChanged: onChanged, cursorColor: primaryTeal, decoration: _inputDecoration(label, icon));
  }

  Widget _buildPasswordField(TextEditingController controller, String label, bool obscure, VoidCallback toggle) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: _inputDecoration(label, Icons.lock_outline).copyWith(
        suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey, size: 20), onPressed: toggle),
      ),
    );
  }

  // --- LOGIC ---
  Future<Map<String, dynamic>> _changePassword(String oldPass, String newPass) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final String rawId = prefs.get('id')?.toString() ?? '0';
    try {
      final response = await http.post(Uri.parse("${baseUrl}api.php?action=change-password"), body: jsonEncode({"user_id": rawId, "old_password": oldPass, "new_password": newPass}));
      return jsonDecode(response.body);
    } catch (e) { return {"success": false, "message": "Connection error"}; }
  }

  Future<void> _handleLogout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  Future<void> _updateProfile(String name, String contact, String address, String qual) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final String rawId = prefs.get('id')?.toString() ?? '0';
    setState(() => isLoading = true);
    try {
      final response = await http.post(Uri.parse("${baseUrl}api.php?action=update-profile"), body: jsonEncode({"id": rawId, "name": name, "contact": contact, "address": address, "qualification": qual}));
      if (jsonDecode(response.body)['success']) {
        await prefs.setString('name', name);
        await prefs.setString('contact', contact);
        await prefs.setString('address', address);
        await prefs.setString('qualification', qual);
        _loadProfileData();
        _showSnackBar("Profile updated!");
      }
    } catch (e) { _showSnackBar("Connection error"); }
    finally { if(mounted) setState(() => isLoading = false); }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(leading: Icon(Icons.photo_library, color: primaryTeal), title: const Text('Upload New Image'), onTap: () { Navigator.pop(context); _pickAndUploadImage(); }),
            if (profilePicName != null && profilePicName!.isNotEmpty)
              ListTile(leading: const Icon(Icons.delete_outline, color: Colors.redAccent), title: const Text('Delete Photo', style: TextStyle(color: Colors.redAccent)), onTap: () { Navigator.pop(context); _showDeleteConfirmation(); }),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Remove Photo?", style: TextStyle(color: primaryTeal, fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to delete your profile picture?", style: TextStyle(color: Colors.grey.shade700)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () { Navigator.pop(context); _deleteImage(); }, child: const Text("Delete", style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  Future<void> _deleteImage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final String rawId = prefs.get('id')?.toString() ?? '0';
    try {
      final response = await http.post(Uri.parse("${baseUrl}api.php?action=delete-profile-pic"), body: jsonEncode({"user_id": rawId}));
      if (jsonDecode(response.body)['success']) {
        await prefs.remove('profile_pic');
        setState(() => profilePicName = null);
        _showSnackBar("Photo removed");
      }
    } catch (e) { _showSnackBar("Error"); }
  }

  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image != null) {
      final Uint8List bytes = await image.readAsBytes();
      _uploadImageWeb(bytes, image.name);
    }
  }

  Future<void> _uploadImageWeb(Uint8List bytes, String fileName) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final String rawId = prefs.get('id')?.toString() ?? '0';
    try {
      var request = http.MultipartRequest('POST', Uri.parse("${baseUrl}api.php?action=upload-profile-pic"));
      request.fields['user_id'] = rawId;
      request.files.add(http.MultipartFile.fromBytes('image', bytes, filename: fileName, contentType: MediaType('image', 'jpeg')));
      var response = await http.Response.fromStream(await request.send());
      var data = jsonDecode(response.body);
      if (data['success']) {
        await prefs.setString('profile_pic', data['profile_pic']);
        setState(() => profilePicName = data['profile_pic']);
        _showSnackBar("Upload successful");
      }
    } catch (e) { _showSnackBar("Upload failed"); }
  }

  void _showSnackBar(String msg) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg))); }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWebWide = screenWidth > 900;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryTeal))
          : SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isWebWide ? screenWidth * 0.2 : 20, vertical: 40),
          child: Column(
            children: [
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: primaryTeal.withOpacity(0.1),
                          child: CircleAvatar(
                            radius: 54,
                            backgroundColor: primaryTeal,
                            child: ClipOval(
                              child: (profilePicName != null && profilePicName!.isNotEmpty)
                                  ? Image.network("${imageBaseUrl}${profilePicName!}?t=${DateTime.now().millisecondsSinceEpoch}", width: 108, height: 108, fit: BoxFit.cover, errorBuilder: (c, e, s) => Text(firstLetter, style: const TextStyle(fontSize: 40, color: Colors.white)))
                                  : Text(firstLetter, style: const TextStyle(fontSize: 40, color: Colors.white)),
                            ),
                          ),
                        ),
                        Positioned(bottom: 0, right: 0, child: GestureDetector(onTap: _showImageOptions, child: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]), child: Icon(Icons.camera_alt, color: primaryTeal, size: 20)))),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
                    Text(userEmail, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              _buildSectionTitle("Account Settings"),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
                child: Column(
                  children: [
                    _buildProfileTile(icon: Icons.person_outline, title: "Edit Profile", onTap: _showEditDialog),
                    _buildProfileTile(icon: Icons.location_on_outlined, title: "Shipping Address"),
                    _buildProfileTile(icon: Icons.lock_outline, title: "Change Password", onTap: _showChangePasswordDialog),
                    _buildProfileTile(icon: Icons.notifications_none_outlined, title: "Notification Settings", isLast: true),
                  ],
                ),
              ),

              // --- ONLY SHOW SUPPORT SECTION IF NOT TEACHER ---
              if (userRole != "teacher") ...[
                const SizedBox(height: 30),
                _buildSectionTitle("Support"),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    children: [
                      _buildProfileTile(icon: Icons.share_outlined, title: "Invite a Friend"),
                      _buildProfileTile(icon: Icons.info_outline, title: "About SGN Online", isLast: true),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(left: 4), child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black54))));

  Widget _buildProfileTile({required IconData icon, required String title, VoidCallback? onTap, bool isLast = false}) {
    return ListTile(
      onTap: onTap,
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: primaryTeal.withOpacity(0.08), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: primaryTeal, size: 22)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
    );
  }
}