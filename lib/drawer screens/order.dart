import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../store_screen.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final Color primaryTeal = const Color(0xFF008080);
  final String BASE_URL = "http://localhost/school_api/api.php";

  // UPDATED: Ab ye direct share/save option khulega
  Future<void> _downloadReceipt(Map<String, String> order) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(30),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("OFFICIAL PAYMENT RECEIPT",
                    style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Divider(),
                pw.SizedBox(height: 20),
                pw.Text("Item Name: ${order['title']}", style: pw.TextStyle(fontSize: 18)),
                pw.Text("Purchase Date: ${order['date']}"),
                pw.Text("Amount Paid: ${order['price']?.replaceAll('₹', 'Rs.')}"),
                pw.Text("Order Status: ${order['status']}"),
                pw.SizedBox(height: 50),
                pw.Divider(),
                pw.Text("Thank you for your purchase. This is a computer-generated receipt.",
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
              ],
            ),
          );
        },
      ),
    );

    // REQUIRED CHANGE: layoutPdf ki jagah sharePdf use kiya hai download ke liye
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Receipt_${order['title']!.replaceAll(' ', '_')}.pdf',
    );
  }

  Future<List<dynamic>> fetchOrders() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String userId = prefs.getString('id') ?? "";

    if (userId.isEmpty) return [];

    final url = Uri.parse("$BASE_URL?action=get-my-orders&user_id=$userId");

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result["success"] == true) {
          return result["data"] ?? [];
        }
      }
      return [];
    } catch (e) {
      debugPrint("Error fetching orders: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: LayoutBuilder(
        builder: (context, constraints) {
          double hPadding = constraints.maxWidth > 600 ? 40 : 20;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 30),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Study Store",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Icon(Icons.shopping_bag_outlined, color: primaryTeal, size: 30),
                      ],
                    ),
                    const SizedBox(height: 25),
                    _buildPromoBanner(),
                    const SizedBox(height: 35),
                    const Text(
                      "My Recent Orders",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 15),
                    FutureBuilder<List<dynamic>>(
                      future: fetchOrders(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 50),
                              child: CircularProgressIndicator(color: primaryTeal),
                            ),
                          );
                        }

                        final List<dynamic> myOrders = snapshot.data ?? [];

                        if (myOrders.isEmpty) return _buildEmptyState();

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: myOrders.length,
                          itemBuilder: (context, index) {
                            var item = myOrders[index];
                            return _buildOrderCard({
                              "title": (item["title"] ?? "Untitled").toString(),
                              "date": (item["date"] ?? "").toString(),
                              "price": "INR ${item["price"] ?? "0"}",
                              "status": (item["status"] ?? "Delivered").toString(),
                            });
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPromoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryTeal, const Color(0xFF00BFA5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Get 20% Off",
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const Text(
                  "On all Semester Notes",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 15),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const StoreScreen()),
                    ).then((_) => setState(() {}));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: primaryTeal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Browse Store", style: TextStyle(fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
          const Icon(Icons.book_online, size: 80, color: Colors.white24),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, String> order) {
    String status = order["status"]!;
    bool isPositive = status == "Delivered" || status == "Available" || status == "Success";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              color: primaryTeal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.description_outlined, color: primaryTeal),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order["title"]!,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  order["date"]!,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                order["price"]!,
                style: TextStyle(fontWeight: FontWeight.bold, color: primaryTeal),
              ),
              const SizedBox(height: 8),

              InkWell(
                onTap: () => _downloadReceipt(order),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.picture_as_pdf, size: 14, color: Colors.blue),
                      SizedBox(width: 4),
                      Text("PDF", style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(Icons.shopping_cart_outlined, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          const Text("You haven't purchased anything yet", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}