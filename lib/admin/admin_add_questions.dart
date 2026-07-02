import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AdminAddQuestion extends StatefulWidget {
  const AdminAddQuestion({super.key});

  @override
  State<AdminAddQuestion> createState() => _AdminAddQuestionState();
}

class _AdminAddQuestionState extends State<AdminAddQuestion> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();
  final TextEditingController _newCategoryController = TextEditingController();

  // Make sure this is your correct local IP if using a real device
  final String apiUrl = "http://localhost/school_api/api.php";

  List<String> _categories = [];
  List _questions = [];
  String? _selectedCategory;
  String? _editingId;
  bool _isLoading = true;
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    await _fetchCategories();
    await _fetchQuestions();
    setState(() => _isLoading = false);
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await http.get(Uri.parse("$apiUrl?action=get_unique_categories"));
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        setState(() {
          _categories = List<String>.from(data['data']);
          if (_categories.isNotEmpty && _selectedCategory == null) {
            _selectedCategory = _categories[0];
          }
        });
      }
    } catch (e) {
      debugPrint("Category Error: $e");
    }
  }

  Future<void> _fetchQuestions() async {
    try {
      final response = await http.get(Uri.parse("$apiUrl?action=get_practice_questions"));
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        setState(() => _questions = data['data']);
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
    }
  }

  // FIXED: Added headers for JSON
  Future<void> _submitQuestion() async {
    if (!_formKey.currentState!.validate() || _selectedCategory == null) return;
    setState(() => _isPosting = true);

    String action = _editingId == null ? "add_practice_question" : "update_practice_question";

    try {
      final response = await http.post(
        Uri.parse("$apiUrl?action=$action"),
        headers: {"Content-Type": "application/json"}, // CRITICAL CHANGE
        body: jsonEncode({
          "id": _editingId,
          "category": _selectedCategory,
          "question_text": _questionController.text.trim(),
          "answer_text": _answerController.text.trim(),
        }),
      );

      final result = jsonDecode(response.body);
      if (result['success'] == true) {
        _resetForm();
        _fetchQuestions();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_editingId == null ? "Posted!" : "Updated!"), backgroundColor: Colors.teal),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      setState(() => _isPosting = false);
    }
  }

  // FIXED: Added headers for JSON
  Future<void> _deleteQuestion(String id) async {
    try {
      final response = await http.post(
        Uri.parse("$apiUrl?action=delete_question"),
        headers: {"Content-Type": "application/json"}, // CRITICAL CHANGE
        body: jsonEncode({"id": id}),
      );
      print("Status Code: ${response.statusCode}");

      final result = jsonDecode(response.body);
      if (result['success'] == true) {
        _fetchQuestions();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Deleted"), backgroundColor: Colors.red));
      }
    } catch (e) {
      debugPrint("Delete Error: $e");
    }
  }

  void _startEditing(Map q) {
    setState(() {
      _editingId = q['id'].toString();
      _questionController.text = q['question_text'];
      _answerController.text = q['answer_text'];
      _selectedCategory = q['category'];
    });
    Scrollable.ensureVisible(_formKey.currentContext!);
  }

  void _resetForm() {
    setState(() {
      _editingId = null;
      _questionController.clear();
      _answerController.clear();
    });
  }

  void _showAddCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add New Category"),
        content: TextField(controller: _newCategoryController, decoration: const InputDecoration(hintText: "e.g. History")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (_newCategoryController.text.isNotEmpty) {
                setState(() {
                  String newCat = _newCategoryController.text.trim();
                  if (!_categories.contains(newCat)) _categories.add(newCat);
                  _selectedCategory = newCat;
                });
                _newCategoryController.clear();
                Navigator.pop(context);
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Manage Questions", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal,
        elevation: 0,
        actions: [IconButton(onPressed: _refreshData, icon: const Icon(Icons.refresh, color: Colors.white))],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_editingId == null ? "Add New Question" : "Edit Question",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                        if (_editingId != null)
                          TextButton(onPressed: _resetForm, child: const Text("Cancel Edit", style: TextStyle(color: Colors.red))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedCategory,
                            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Category"),
                            items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                            onChanged: (val) => setState(() => _selectedCategory = val),
                          ),
                        ),
                        IconButton(onPressed: _showAddCategoryDialog, icon: const Icon(Icons.add_circle, color: Colors.teal)),
                      ],
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _questionController,
                      maxLines: 3,
                      decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Question Text"),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _answerController,
                      decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Correct Answer"),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: _editingId == null ? Colors.teal : Colors.orange),
                        onPressed: _isPosting ? null : _submitQuestion,
                        child: _isPosting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(_editingId == null ? "POST TO APP" : "UPDATE QUESTION", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Align(alignment: Alignment.centerLeft, child: Text("Existing Questions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _questions.length,
              itemBuilder: (context, index) {
                final q = _questions[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(q['question_text'], maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(q['category'], style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.w500)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () => _startEditing(q)),
                        IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => _deleteQuestion(q['id'].toString())),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}