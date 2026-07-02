import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Note: Ensure you have created ai_chat_screen.dart
import '../ai_chat_screen.dart';


// --- MODEL CLASS ---
class SupportTicket {
  final int id;
  final String userId;
  final String userType;
  final int adminId;
  final String message;
  final String? reply;
  final String status;
  final String createdAt;

  SupportTicket({
    required this.id,
    required this.userId,
    required this.userType,
    required this.adminId,
    required this.message,
    this.reply,
    required this.status,
    required this.createdAt,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: int.parse(json['id'].toString()),
      userId: (json['user_id'] ?? json['student_id'] ?? "0").toString(),
      userType: json['user_type'] ?? "user",
      adminId: int.parse((json['admin_id'] ?? "1").toString()),
      message: json['message'] ?? '',
      reply: json['reply'],
      status: json['status'] ?? 'open',
      createdAt: json['created_at'] ?? '',
    );
  }
}

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final Color primaryTeal = const Color(0xFF008080);
  final TextEditingController _chatController = TextEditingController();

  List<dynamic> allFaqs = [];
  List<dynamic> displayedFaqs = [];
  List<SupportTicket> myTickets = [];
  bool isLoading = true;
  String userId = "";

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => isLoading = true);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('id') ?? "0";
    });
    await fetchFaqs();
    await fetchMyTickets();
    setState(() => isLoading = false);
  }

  Future<void> fetchFaqs() async {
    try {
      final response = await http.get(Uri.parse("http://localhost/school_api/api.php?action=get-faqs&type=user"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            allFaqs = data['data'];
            displayedFaqs = allFaqs;
          });
        }
      }
    } catch (e) {
      debugPrint("FAQ Error: $e");
    }
  }

  Future<void> fetchMyTickets() async {
    if (userId == "0") return;
    try {
      final response = await http.get(Uri.parse("http://localhost/school_api/api.php?action=get-my-tickets&user_id=$userId&user_type=user"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            myTickets = (data['data'] as List)
                .map((item) => SupportTicket.fromJson(item))
                .toList();
          });
        }
      }
    } catch (e) {
      debugPrint("Tickets Error: $e");
    }
  }

  Future<void> _sendChatReply(int ticketId) async {
    if (_chatController.text.trim().isEmpty) return;

    final response = await http.post(
      Uri.parse("http://localhost/school_api/api.php?action=raise-ticket"),
      body: json.encode({
        "user_id": userId,
        "user_type": "user",
        "message": _chatController.text.trim()
      }),
    );

    if (json.decode(response.body)['success']) {
      _chatController.clear();
      fetchMyTickets();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Reply sent!"), backgroundColor: Colors.teal),
      );
    }
  }

  void _handleNewTicketRequest() {
    bool hasActiveTicket = myTickets.any((t) => t.status.toLowerCase() == 'open');

    if (hasActiveTicket) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You already have an active ticket. Please wait or chat in the existing one."),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      _showRaiseTicketDialog();
    }
  }

  void _showRaiseTicketDialog() {
    TextEditingController msgController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: primaryTeal.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(Icons.admin_panel_settings_rounded, color: primaryTeal, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text("Contact Admin", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade300)),
                child: TextField(
                  controller: msgController,
                  maxLines: 4,
                  decoration: const InputDecoration(hintText: "Type message...", border: InputBorder.none, contentPadding: EdgeInsets.all(15)),
                ),
              ),
              const SizedBox(height: 25),
              Row(
                children: [
                  Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel", style: TextStyle(color: Colors.grey.shade600)))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: primaryTeal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () async {
                        if (msgController.text.trim().isNotEmpty) {
                          final response = await http.post(
                            Uri.parse("http://localhost/school_api/api.php?action=raise-ticket"),
                            body: json.encode({
                              "user_id": userId,
                              "user_type": "user",
                              "message": msgController.text.trim()
                            }),
                          );
                          if (json.decode(response.body)['success']) {
                            Navigator.pop(context);
                            fetchMyTickets();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sent!")));
                          }
                        }
                      },
                      child: const Text("Send", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _runFilter(String enteredKeyword) {
    List<dynamic> results = (enteredKeyword.isEmpty)
        ? allFaqs
        : allFaqs.where((f) => f["question"].toLowerCase().contains(enteredKeyword.toLowerCase())).toList();
    setState(() => displayedFaqs = results);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text("Help & Support", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          bottom: TabBar(
            labelColor: primaryTeal,
            unselectedLabelColor: Colors.grey,
            indicatorColor: primaryTeal,
            tabs: const [Tab(text: "FAQs"), Tab(text: "My Tickets")],
          ),
        ),
        // --- UPDATED FLOATING ACTION BUTTON ---
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              heroTag: "ai_tutor_fab",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) =>  AIChatScreen()),
                );
              },
              backgroundColor: Colors.white,
              child: const Text("🤖", style: TextStyle(fontSize: 24)),
            ),
            const SizedBox(height: 12),
            FloatingActionButton.extended(
              heroTag: "admin_contact_fab",
              onPressed: _handleNewTicketRequest,
              backgroundColor: primaryTeal,
              icon: const Icon(Icons.add_comment),
              label: const Text("Contact Admin"),
            ),
          ],
        ),
        body: isLoading ? Center(child: CircularProgressIndicator(color: primaryTeal))
            : TabBarView(children: [_buildFaqTab(), _buildTicketsTab()]),
      ),
    );
  }

  Widget _buildFaqTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSearchBar(),
        const SizedBox(height: 20),
        ...displayedFaqs.map((faq) => _buildFaqItem(faq)).toList(),
        const SizedBox(height: 20),
        _buildContactCard(),
        const SizedBox(height: 70),
      ],
    );
  }

  Widget _buildTicketsTab() {
    return myTickets.isEmpty
        ? const Center(child: Text("No queries raised yet."))
        : ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: myTickets.length,
      itemBuilder: (context, index) {
        final ticket = myTickets[index];
        bool isResolved = ticket.status.toLowerCase() == 'resolved' || ticket.status.toLowerCase() == 'solved';

        List<String> chatHistory = ticket.message.split('|');

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: isResolved ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
              child: Icon(isResolved ? Icons.check : Icons.message, color: isResolved ? Colors.green : Colors.orange, size: 18),
            ),
            title: Text(chatHistory.last.trim(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text("Status: ${ticket.status.toUpperCase()}", style: TextStyle(fontSize: 11, color: isResolved ? Colors.green : Colors.orange)),
            children: [
              Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  children: [
                    ...chatHistory.map((msg) => _buildChatBubble(msg.trim(), isUser: true)).toList(),
                    if (ticket.reply != null) _buildChatBubble(ticket.reply!, isUser: false),
                    if (!isResolved) ...[
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _chatController,
                              decoration: InputDecoration(
                                hintText: "Reply to admin...",
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            backgroundColor: primaryTeal,
                            child: IconButton(
                              icon: const Icon(Icons.send, color: Colors.white, size: 18),
                              onPressed: () => _sendChatReply(ticket.id),
                            ),
                          )
                        ],
                      ),
                    ]
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatBubble(String text, {required bool isUser}) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        decoration: BoxDecoration(
          color: isUser ? primaryTeal : Colors.grey.shade200,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15),
            topRight: const Radius.circular(15),
            bottomLeft: Radius.circular(isUser ? 15 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 15),
          ),
        ),
        child: Text(text, style: TextStyle(color: isUser ? Colors.white : Colors.black87, fontSize: 13)),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: TextField(onChanged: _runFilter, decoration: InputDecoration(hintText: "Search FAQs...", prefixIcon: Icon(Icons.search, color: primaryTeal), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 16))),
    );
  }

  Widget _buildFaqItem(dynamic faq) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
      child: ExpansionTile(iconColor: primaryTeal, title: Text(faq["question"], style: const TextStyle(fontWeight: FontWeight.w600)), children: [Padding(padding: const EdgeInsets.all(16), child: Text(faq["answer"], style: TextStyle(color: Colors.grey.shade600)))]),
    );
  }

  Widget _buildContactCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [primaryTeal, const Color(0xFF2980B9)]), borderRadius: BorderRadius.circular(25)),
      child: Column(children: [
        const Text("Still need help?", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: ElevatedButton.icon(onPressed: _launchEmail, icon: const Icon(Icons.email, size: 18), label: const Text("Email"), style: ElevatedButton.styleFrom(foregroundColor: primaryTeal, backgroundColor: Colors.white))),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton.icon(onPressed: _launchWhatsApp, icon: const Icon(Icons.chat, size: 18), label: const Text("WhatsApp"), style: ElevatedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: const Color(0xFF25D366)))),
        ])
      ]),
    );
  }

  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(scheme: 'mailto', path: 'info@sgnsolutions.in');
    await launchUrl(emailUri);
  }

  Future<void> _launchWhatsApp() async {
    await launchUrl(Uri.parse("https://wa.me/7357772213"), mode: LaunchMode.externalApplication);
  }
}