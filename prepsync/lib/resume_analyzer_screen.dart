import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:percent_indicator/percent_indicator.dart';
import 'dart:convert';
import 'dart:io';
import 'package:prepsync/api_config.dart';

class ResumeAnalyzerScreen extends StatefulWidget {
  final int userId;
  const ResumeAnalyzerScreen({required this.userId, super.key});

  @override
  State<ResumeAnalyzerScreen> createState() => _ResumeAnalyzerScreenState();
}

class _ResumeAnalyzerScreenState extends State<ResumeAnalyzerScreen> {
  bool _isLoading = false;
  File? _selectedFile;
  String _fileName = "";
  Map<String, dynamic>? _result;
  final TextEditingController _roleController = TextEditingController(text: "Software Engineer");

  Future<void> _pickPDF() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _fileName = result.files.single.name;
        _result = null;
      });
    }
  }

  Future<void> _analyzeResume() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please upload a resume first.")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/analyze-resume'));
      
      // Add the file
      request.files.add(await http.MultipartFile.fromPath('resume', _selectedFile!.path));
      
      // CRITICAL: Send User ID so backend can save the score
      request.fields['role'] = _roleController.text;
      request.fields['user_id'] = widget.userId.toString(); 

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() => _result = data);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Analysis failed: ${response.body}")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connection error. Check backend.")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Resume Analyzer", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0A2540),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Target Role:", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            const SizedBox(height: 5),
            TextField(
              controller: _roleController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "e.g. Data Analyst, Frontend Developer",
              ),
            ),
            const SizedBox(height: 20),
            
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  Icon(Icons.cloud_upload_outlined, size: 50, color: Colors.teal),
                  const SizedBox(height: 10),
                  Text(_fileName.isEmpty ? "No PDF Selected" : _fileName, 
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _pickPDF,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                    child: const Text("Select Resume (PDF)"),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            ElevatedButton(
              onPressed: _isLoading ? null : _analyzeResume,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A2540),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("Analyze My Resume"),
            ),

            const SizedBox(height: 30),

            if (_result != null) ...[
              const Divider(thickness: 2),
              const SizedBox(height: 10),
              Text("Analysis Results", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF0A2540))),
              const SizedBox(height: 20),
              
              Center(
                child: CircularPercentIndicator(
                  radius: 80.0,
                  lineWidth: 12.0,
                  percent: (_result!['score'] ?? 0) / 100,
                  center: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("${_result!['score']}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 40)),
                      Text("Score", style: GoogleFonts.poppins(color: Colors.grey)),
                    ],
                  ),
                  progressColor: _result!['score'] > 70 ? Colors.green : Colors.orange,
                  backgroundColor: Colors.grey[200]!,
                  circularStrokeCap: CircularStrokeCap.round,
                  animation: true,
                ),
              ),
              
              const SizedBox(height: 30),
              Text("🚀 Room for Improvement:", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              
              ...List<Widget>.from((_result!['feedback'] as List).map((point) => 
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_outline, color: Colors.teal, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(point, style: GoogleFonts.poppins(fontSize: 14))),
                    ],
                  ),
                )
              )),
            ]
          ],
        ),
      ),
    );
  }
}