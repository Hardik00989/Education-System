import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AdminAddStudyMaterial extends StatefulWidget {
  const AdminAddStudyMaterial({super.key});

  @override
  State<AdminAddStudyMaterial> createState() => _AdminAddStudyMaterialState();
}

class _AdminAddStudyMaterialState extends State<AdminAddStudyMaterial> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  String? _selectedClass;
  String? _selectedSubject;
  String? _editingId;

  List<String> classList = [];
  List<String> subjectList = [];
  List allMaterials = [];

  bool _isLoading = true;
  bool _isProcessing = false;

  final String baseUrl = "http://localhost/school_api/api.php";

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    try {
      final configRes = await http.get(Uri.parse("$baseUrl?action=get_classes_and_subjects"));
      final listRes = await http.get(Uri.parse("$baseUrl?action=get_all_study_materials"));
      final configData = jsonDecode(configRes.body);
      final listData = jsonDecode(listRes.body);

      setState(() {
        if (configData['success']) {
          classList = List<String>.from(configData['classes']);
          subjectList = List<String>.from(configData['subjects']);
        }
        if (listData['success']) {
          allMaterials = listData['data'];
        }
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Form ko handle karne wala function
  void _openMaterialForm({Map? item}) {
    if (item != null) {
      _editingId = item['id'].toString();
      _titleController.text = item['title'];
      _priceController.text = item['price'];
      _selectedClass = item['target_class'];
      _selectedSubject = item['subject_name'];
    } else {
      _resetForm();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600), // Web compatibility
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
                ),
                padding: const EdgeInsets.all(25),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                        const SizedBox(height: 20),
                        Text(_editingId == null ? "Add New Material" : "Update Material",
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal)),
                        const SizedBox(height: 25),
                        _buildField(_titleController, "Material Title", Icons.title),
                        const SizedBox(height: 15),
                        _buildDropdown("Select Class", classList, _selectedClass, (v) => setModalState(() => _selectedClass = v)),
                        const SizedBox(height: 15),
                        _buildDropdown("Select Subject", subjectList, _selectedSubject, (v) => setModalState(() => _selectedSubject = v)),
                        const SizedBox(height: 15),
                        _buildField(_priceController, "Price (₹)", Icons.currency_rupee, isNumeric: true),
                        const SizedBox(height: 25),
                        _isProcessing
                            ? const CircularProgressIndicator()
                            : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            minimumSize: const Size(double.infinity, 55),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          ),
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              setModalState(() => _isProcessing = true);
                              await _processData();
                              setModalState(() => _isProcessing = false);
                              Navigator.pop(context); // Close sheet
                            }
                          },
                          child: Text(_editingId == null ? "UPLOAD NOW" : "UPDATE NOW",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _processData() async {
    String action = _editingId == null ? "add_study_material" : "update_study_material";
    Map<String, dynamic> body = {
      "title": _titleController.text.trim(),
      "price": _priceController.text.trim().isEmpty ? "0" : _priceController.text.trim(),
      "target_class": _selectedClass,
      "subject_name": _selectedSubject,
      "status": "Available",
    };
    if (_editingId != null) body["id"] = _editingId;

    try {
      final response = await http.post(Uri.parse("$baseUrl?action=$action"),
          headers: {"Content-Type": "application/json"}, body: jsonEncode(body));
      if (jsonDecode(response.body)['success']) {
        _resetForm();
        _fetchInitialData();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Success!"), backgroundColor: Colors.teal));
      }
    } catch (e) {
      debugPrint("Process Error: $e");
    }
  }

  Future<void> _deleteData(String id) async {
    setState(() => _isLoading = true);
    await http.post(Uri.parse("$baseUrl?action=delete_study_material"),
        headers: {"Content-Type": "application/json"}, body: jsonEncode({"id": id}));
    _fetchInitialData();
  }

  void _resetForm() {
    _titleController.clear();
    _priceController.clear();
    _selectedClass = null;
    _selectedSubject = null;
    _editingId = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Study Materials", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.teal,
        elevation: 0,
      ),
      // --- FLOATING ACTION BUTTON ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openMaterialForm(),
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("ADD MATERIAL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isWide = constraints.maxWidth > 800;
          bool isMedium = constraints.maxWidth > 500 && constraints.maxWidth <= 800;

          return _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.teal))
              : Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats Header
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_stories, color: Colors.teal, size: 28),
                        const SizedBox(width: 12),
                        const Text("Material Library", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Chip(label: Text("${allMaterials.length} Items Available")),
                      ],
                    ),
                  ),
                  // Grid List
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isWide ? 3 : (isMedium ? 2 : 1),
                        mainAxisExtent: 160,
                        crossAxisSpacing: 15,
                        mainAxisSpacing: 15,
                      ),
                      itemCount: allMaterials.length,
                      itemBuilder: (context, index) => _buildModernCard(allMaterials[index]),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModernCard(Map item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Stack(
        children: [
          Positioned(top: 0, left: 0, right: 0, child: Container(height: 4, decoration: const BoxDecoration(color: Colors.teal, borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    _buildBadge(item['price'] == "0" ? "FREE" : "₹${item['price']}", item['price'] == "0" ? Colors.green : Colors.teal),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildIconLabel(Icons.book_outlined, item['subject_name'], Colors.blue),
                    const SizedBox(width: 15),
                    _buildIconLabel(Icons.school_outlined, item['target_class'], Colors.orange),
                  ],
                ),
                const Spacer(),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(icon: const Icon(Icons.edit_note, color: Colors.blue), onPressed: () => _openMaterialForm(item: item)),
                    IconButton(icon: const Icon(Icons.delete_sweep, color: Colors.redAccent), onPressed: () => _showDeleteConfirm(item['id'].toString())),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- REUSABLE UI COMPONENTS ---
  Widget _buildField(TextEditingController controller, String label, IconData icon, {bool isNumeric = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.teal),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
      validator: (val) => val!.isEmpty ? "Required" : null,
    );
  }

  Widget _buildDropdown(String hint, List<String> items, String? value, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(15)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          hint: Text(hint),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildIconLabel(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
      ],
    );
  }

  void _showDeleteConfirm(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Material?"),
        content: const Text("Are you sure you want to remove this item?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(onPressed: () { Navigator.pop(context); _deleteData(id); }, child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}