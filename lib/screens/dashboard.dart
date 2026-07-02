import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:new_task/admin/admin_home_screen.dart';
import 'package:new_task/admin/manage_schedule_screen.dart';
import 'package:new_task/admin/allfeedbacks.dart';
import 'package:new_task/admin/manage_users.dart';
import 'package:new_task/screens/Login_screen.dart';
import 'package:new_task/screens/teacher_home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Drawer screens
import '../drawer screens/Doubt.dart';
import '../drawer screens/order.dart';
import '../drawer screens/profile_screen.dart';
import '../drawer screens/student_feedback.dart';
import '../drawer screens/terms_conditions.dart';
import '../drawer screens/web_version.dart';

// Dashboard screens
import 'dashboardscreens/batches_screen.dart';
import 'dashboardscreens/student_attendence.dart';
import 'dashboardscreens/help_screen.dart';
import 'dashboardscreens/home_screen.dart';
import 'dashboardscreens/notification.dart';
import 'dashboardscreens/assignment_screen.dart';
import 'dashboardscreens/students_assignment_screen.dart';
import 'dashboardscreens/teacher_attendence_screen.dart';
import 'dashboardscreens/teacher_help.dart';
import 'dashboardscreens/teacher_notification.dart';
import 'dashboardscreens/teacher_doubt_screen.dart';

// Admin screens (Inhe aap create kar lena)
// import 'admin_screens/admin_home.dart';
// import 'admin_screens/manage_users.dart';
// import 'admin_screens/all_feedbacks.dart';

class DashboardScreen extends StatefulWidget {
  final String userType;
  const DashboardScreen({super.key, required this.userType});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int bottomNavIndex = 0;
  String displayEmail = "Loading...";
  String displayName = "User";
  String userId = "";
  String? profilePicName;

  final String imageBaseUrl = "http://localhost/school_api/uploads/profiles/";
  int pendingDoubtsCount = 0;
  int unreadNotificationCount = 0;
  Timer? _badgeTimer;

  late final List<Widget> userScreens;
  late final List<Widget> teacherScreens;
  late final List<Widget> adminScreens; // New List for Admin
  final Color primaryTeal = const Color(0xFF008080);

  @override
  void initState() {
    super.initState();
    _loadUserData();

    // Existing Lists
    userScreens = [const HomeScreen(), const BatchesScreen(), const StudentAssignmentScreen(), const StudentAttendanceScreen(), const HelpScreen()];
    teacherScreens = [const TeacherHomeScreen(), const AssignmentScreen(), const TeacherDoubtScreen(), const TeacherAttendanceScreen(), const TeacherHelpScreen()];

    // Admin Specific Lists
    adminScreens = [
      const AdminHomeScreen(), // Replace with AdminHomeScreen if created
      const ManageUsersScreen(), // Replace with ManageUsers if created
      const AllfeedbacksScreen(), // Replace with AllFeedbacks if created
      const AdminhelpScreen(),
    ];

    _startBadgeTimer();
  }

  @override
  void dispose() {
    _badgeTimer?.cancel();
    super.dispose();
  }

  void _startBadgeTimer() {
    _fetchAllBadgeCounts();
    _badgeTimer = Timer.periodic(const Duration(seconds: 30), (timer) => _fetchAllBadgeCounts());
  }

  Future<void> _fetchAllBadgeCounts() async {
    if (userId.isEmpty) return;
    try {
      final response = await http.get(Uri.parse("http://localhost/school_api/api.php?action=get-notifications&user_id=$userId"));
      final data = json.decode(response.body);
      if (data['success'] && mounted) {
        List allNotifs = data['data'];
        setState(() => unreadNotificationCount = allNotifs.where((n) => n["is_read"].toString() == "0").length);
      }
    } catch (e) { debugPrint("Notif Badge Error: $e"); }

    if (widget.userType.toLowerCase() == "teacher") {
      try {
        final response = await http.get(Uri.parse("http://localhost/school_api/api.php?action=get-pending-count&teacher_id=$userId"));
        final data = json.decode(response.body);
        if (data['success'] && mounted) setState(() => pendingDoubtsCount = data['count']);
      } catch (e) { debugPrint("Doubt Badge Error: $e"); }
    }
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        displayName = prefs.getString('name') ?? "User";
        displayEmail = prefs.getString('email') ?? "No Email Found";
        userId = prefs.getString('id') ?? "";
        profilePicName = prefs.getString('profile_pic');
      });
    }
    _fetchAllBadgeCounts();
  }

  void _showNoImageDialog() {
    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (context) => Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          constraints: const BoxConstraints(maxWidth: 350),
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: EdgeInsets.zero,
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: primaryTeal.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(Icons.image_not_supported_outlined, color: primaryTeal, size: 35),
                ),
                const SizedBox(height: 15),
                Text("No Profile Picture", style: TextStyle(color: primaryTeal, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: const Text("You haven't uploaded a profile picture yet. Add one from the Profile section.", textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontSize: 13)),
            actionsPadding: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryTeal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12)),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Got it", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(10),
          child: InteractiveViewer(child: Image.network("$imageUrl?t=${DateTime.now().millisecondsSinceEpoch}", fit: BoxFit.contain)),
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(bool hasNotifs) {
    return Stack(children: [
      IconButton(icon: const Icon(Icons.notifications_none, size: 28), onPressed: () {
        final type = widget.userType.toLowerCase();
        type == "teacher" ? openWithSameAppBar(const TeacherNotificationScreen()) : openWithSameAppBar(const NotificationScreen());
        Future.delayed(const Duration(seconds: 2), () => _fetchAllBadgeCounts());
      }),
      if (unreadNotificationCount > 0)
        Positioned(right: 8, top: 8, child: Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)), constraints: const BoxConstraints(minWidth: 16, minHeight: 16), child: Text('$unreadNotificationCount', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center))),
    ]);
  }

  Future<void> _handleLogout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
  }

  void openWithSameAppBar(Widget screen) {
    final String type = widget.userType.toLowerCase();
    String title = "SGN Online Classes";
    if (type == "teacher") title = "Teacher's Dashboard";
    if (type == "admin") title = "Admin Panel";

    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      appBar: AppBar(elevation: 0, backgroundColor: primaryTeal, iconTheme: const IconThemeData(color: Colors.white), title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18)), actions: [_buildNotificationIcon(true)]),
      body: screen,
    ))).then((_) => _loadUserData());
  }

  @override
  Widget build(BuildContext context) {
    final String type = widget.userType.toLowerCase();
    final bool isTeacher = type == "teacher";
    final bool isAdmin = type == "admin";

    // Select Screens
    List<Widget> screens;
    if (isAdmin) {
      screens = adminScreens;
    } else if (isTeacher) {
      screens = teacherScreens;
    } else {
      screens = userScreens;
    }

    return Scaffold(
      appBar: AppBar(
          elevation: 2,
          backgroundColor: primaryTeal,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
              isAdmin ? "Admin Dashboard" : (isTeacher ? "Teacher Dashboard" : "SGN Online Classes"),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)
          ),
          actions: [_buildNotificationIcon(true)]
      ),
      body: AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: screens[bottomNavIndex]),
      bottomNavigationBar: BottomNavigationBar(
          currentIndex: bottomNavIndex,
          items: isAdmin ? _adminBottomNav() : (isTeacher ? _teacherBottomNav() : _userBottomNav()),
          selectedItemColor: primaryTeal,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          onTap: (index) => setState(() => bottomNavIndex = index)
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [primaryTeal, const Color(0xFF2980B9)])),
              accountName: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              accountEmail: Text(displayEmail),
              currentAccountPicture: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                offset: const Offset(20, 85),
                constraints: const BoxConstraints(maxWidth: 150),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (value) {
                  if (value == 'view') {
                    if (profilePicName != null && profilePicName!.isNotEmpty) {
                      _showFullImageDialog(context, "$imageBaseUrl$profilePicName");
                    } else {
                      _showNoImageDialog();
                    }
                  } else if (value == 'profile') {
                    Navigator.pop(context);
                    openWithSameAppBar(const ProfileScreen());
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'view', height: 35, child: Row(children: [Icon(Icons.photo_outlined, color: primaryTeal, size: 18), const SizedBox(width: 8), const Text("View Photo", style: TextStyle(fontSize: 13))])),
                  PopupMenuItem(value: 'profile', height: 35, child: Row(children: [Icon(Icons.person_outline, color: primaryTeal, size: 18), const SizedBox(width: 8), const Text("Profile", style: TextStyle(fontSize: 13))])),
                ],
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: ClipOval(
                    child: (profilePicName != null && profilePicName!.isNotEmpty)
                        ? Image.network("$imageBaseUrl$profilePicName?t=${DateTime.now().millisecondsSinceEpoch}", width: 90, height: 90, fit: BoxFit.cover, errorBuilder: (c, e, s) => Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : "U", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryTeal)))
                        : Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : "U", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryTeal)),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _drawerItem(Icons.home_outlined, "Home", () { Navigator.pop(context); setState(() => bottomNavIndex = 0); }),

                  if (isAdmin) ...[
                    _drawerItem(Icons.admin_panel_settings_outlined, "Admin Settings", () {}),
                    _drawerItem(Icons.analytics_outlined, "Reports", () {}),
                  ] else if (isTeacher) ...[
                    _drawerItem(Icons.laptop_mac, "App Version", () { Navigator.pop(context); openWithSameAppBar(const WebVersionScreen()); }),
                    _drawerItem(Icons.gavel_outlined, "Terms & Conditions", () { Navigator.pop(context); openWithSameAppBar(const TermsScreen()); }),
                  ] else ...[
                    _drawerItem(Icons.help_outline, "Doubt", () { Navigator.pop(context); openWithSameAppBar(const DoubtScreen()); }),
                    _drawerItem(Icons.shopping_bag_outlined, "My Orders", () { Navigator.pop(context); openWithSameAppBar(const OrderScreen()); }),
                    _drawerItem(Icons.rate_review_outlined, "Teacher Feedback", () async {
                      Navigator.pop(context);
                      SharedPreferences prefs = await SharedPreferences.getInstance();
                      String studentClass = prefs.getString('studentClass') ?? "";
                      openWithSameAppBar(FeedbackScreen(studentId: userId, studentClass: studentClass));
                    }),
                    _drawerItem(Icons.language, "Web Version", () { Navigator.pop(context); openWithSameAppBar(const WebVersionScreen()); }),
                  ],

                  const Divider(),
                  _drawerItem(Icons.logout_rounded, "Logout", () => _handleLogout(), color: Colors.redAccent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Bottom Nav Helpers ---
  List<BottomNavigationBarItem> _userBottomNav() => const [
    BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
    BottomNavigationBarItem(icon: Icon(Icons.collections_bookmark_outlined), activeIcon: Icon(Icons.collections_bookmark), label: 'Batches'),
    BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), activeIcon: Icon(Icons.assignment), label: 'Assignments'),
    BottomNavigationBarItem(icon: Icon(Icons.check_circle_outline), activeIcon: Icon(Icons.check_circle), label: 'Attendance'),
    BottomNavigationBarItem(icon: Icon(Icons.help_outline), activeIcon: Icon(Icons.help), label: 'Help'),
  ];

  List<BottomNavigationBarItem> _teacherBottomNav() => [
    const BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
    const BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), activeIcon: Icon(Icons.assignment), label: 'Assignments'),
    BottomNavigationBarItem(icon: Stack(children: [const Icon(Icons.question_answer_outlined), if (pendingDoubtsCount > 0) Positioned(right: 0, top: 0, child: Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)), constraints: const BoxConstraints(minWidth: 14, minHeight: 14), child: Text('$pendingDoubtsCount', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center)))]), activeIcon: const Icon(Icons.question_answer), label: 'Doubts'),
    const BottomNavigationBarItem(icon: Icon(Icons.check_circle_outline), activeIcon: Icon(Icons.check_circle), label: 'Attendance'),
    const BottomNavigationBarItem(icon: Icon(Icons.help_outline), activeIcon: Icon(Icons.help), label: 'Help'),
  ];

  List<BottomNavigationBarItem> _adminBottomNav() => const [
    BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
    BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people), label: 'Users'),
    BottomNavigationBarItem(icon: Icon(Icons.rate_review_outlined), activeIcon: Icon(Icons.rate_review), label: 'Feedbacks'),
    BottomNavigationBarItem(icon: Icon(Icons.help_outline), activeIcon: Icon(Icons.help), label: 'Help'),
  ];

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap, {Color? color}) {
    return ListTile(leading: Icon(icon, color: color ?? Colors.black87), title: Text(title, style: TextStyle(color: color ?? Colors.black87, fontWeight: FontWeight.w500)), onTap: onTap);
  }
}