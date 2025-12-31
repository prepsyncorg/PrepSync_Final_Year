// lib/create_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:prepsync/dashboard_screen.dart';

// 1. IMPORT YOUR NEW API_CONFIG.DART FILE
import 'package:prepsync/api_config.dart';

class CreateProfileScreen extends StatefulWidget {
  final int userId;
  final String? initialName;
  const CreateProfileScreen({required this.userId, this.initialName, super.key});

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;

  final _page1Key = GlobalKey<FormState>();
  final _page2Key = GlobalKey<FormState>();
  final _page3Key = GlobalKey<FormState>();

  late TextEditingController _nameController;
  final _headlineController = TextEditingController();
  final _universityController = TextEditingController();
  final _cityController = TextEditingController();
  final _skillsController = TextEditingController();
  final _otherQualificationController = TextEditingController();
  final _otherRoleController = TextEditingController();

  String? _selectedQualification;
  String? _selectedGradYear;
  String? _selectedRole;

  final List<String> _qualifications = [
    'B.Tech / B.E. - Computer Science & Engineering',
    'B.Tech / B.E. - Information Technology',
    'B.Tech / B.E. - Electronics & Telecommunication',
    'MCA (Master of Computer Applications)',
    'BCA (Bachelor of Computer Applications)',
    'BSc - Computer Science',
    'Other'
  ];
  
  final List<String> _gradYears = List<String>.generate(8, (i) => (DateTime.now().year - 2 + i).toString());

  final List<String> _roles = [
    'Software Development Engineer (SDE)',
    'Frontend Developer',
    'Backend Developer',
    'Full-Stack Developer',
    'Data Analyst',
    'QA / Test Engineer',
    'DevOps Engineer',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  Future<void> _submitProfile() async {
    if (!(_page3Key.currentState?.validate() ?? false)) {
      _showSnackBar('Please fill all required fields on this page.');
      return;
    }
    
    setState(() => _isLoading = true);

    // 2. USE THE 'baseUrl' FROM YOUR CONFIG FILE
    // No more hard-coded IP!
    const url = '$baseUrl/create-profile';
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': widget.userId,
          'name': _nameController.text,
          'headline': _headlineController.text,
          'education': _selectedQualification == 'Other' ? _otherQualificationController.text : _selectedQualification,
          'university': _universityController.text,
          'graduation_year': _selectedGradYear,
          'city': _cityController.text,
          'role_preference': _selectedRole == 'Other' ? _otherRoleController.text : _selectedRole,
          'skills': _skillsController.text,
        }),
      );

      if (!mounted) return;
      if (response.statusCode == 201) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DashboardScreen(userId: widget.userId)),
        );
      } else {
        final responseData = json.decode(response.body);
        _showSnackBar(responseData['message'] ?? 'An error occurred.');
      }
    } catch (e) {
      _showSnackBar('Could not connect to the server.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _nextPage() {
    GlobalKey<FormState> currentKey;
    if (_currentPage == 0) currentKey = _page1Key;
    else currentKey = _page2Key;

    if (!(currentKey.currentState?.validate() ?? false)) return;

    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Setup Your Profile (${_currentPage + 1}/3)'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            tween: Tween<double>(begin: _currentPage / 3.0, end: (_currentPage + 1) / 3.0),
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              backgroundColor: const Color.fromRGBO(0, 150, 136, 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (page) => setState(() => _currentPage = page),
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildPage(key: _page1Key, title: 'Personal Details', children: _buildPageOne()),
                _buildPage(key: _page2Key, title: 'Educational Background', children: _buildPageTwo()),
                _buildPage(key: _page3Key, title: 'Career Goals', children: _buildPageThree()),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              // *** THIS IS THE LINE I FIXED (removed extra 'mainAxisAlignment:') ***
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentPage > 0)
                  TextButton.icon(onPressed: _previousPage, icon: const Icon(Icons.arrow_back), label: const Text('Previous')),
                const Spacer(),
                if (_isLoading)
                  const CircularProgressIndicator()
                else
                  ElevatedButton.icon(
                    onPressed: _currentPage == 2 ? _submitProfile : _nextPage,
                    icon: Icon(_currentPage == 2 ? Icons.check_circle_outline : Icons.arrow_forward),
                    label: Text(_currentPage == 2 ? 'Finish Setup' : 'Next'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage({required GlobalKey<FormState> key, required String title, required List<Widget> children}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(key: key, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal)),
        const SizedBox(height: 24),
        ...children
      ])),
    );
  }

  List<Widget> _buildPageOne() {
    return [
      TextFormField(
        controller: _nameController,
        decoration: const InputDecoration(labelText: 'Full Name*', border: OutlineInputBorder()),
        validator: (value) => (value == null || value.isEmpty) ? 'Please enter your name' : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _headlineController,
        decoration: const InputDecoration(labelText: 'Profile Headline*', hintText: 'e.g., Aspiring Software Engineer', border: OutlineInputBorder()),
        validator: (value) => (value == null || value.isEmpty) ? 'Please enter a headline' : null,
      ),
    ];
  }

  List<Widget> _buildPageTwo() {
    return [
      DropdownButtonFormField<String>(
        value: _selectedQualification,
        decoration: const InputDecoration(labelText: 'Highest Qualification*', border: OutlineInputBorder()),
        items: _qualifications.map((String value) {
          return DropdownMenuItem<String>(value: value, child: Text(value, overflow: TextOverflow.ellipsis));
        }).toList(),
        onChanged: (newValue) => setState(() => _selectedQualification = newValue),
        validator: (value) => value == null ? 'Please select a qualification' : null,
        isExpanded: true,
      ),
      if (_selectedQualification == 'Other') ...[
        const SizedBox(height: 16),
        TextFormField(
          controller: _otherQualificationController,
          decoration: const InputDecoration(labelText: 'Please specify other qualification*', border: OutlineInputBorder()),
          validator: (value) => (value == null || value.isEmpty) ? 'This field is required' : null,
        ),
      ],
      const SizedBox(height: 16),
      TextFormField(
        controller: _universityController,
        decoration: const InputDecoration(labelText: 'College/University Name*', border: OutlineInputBorder()),
        validator: (value) => (value == null || value.isEmpty) ? 'This field is required' : null,
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        value: _selectedGradYear,
        decoration: const InputDecoration(labelText: 'Graduation Year*', border: OutlineInputBorder()),
        items: _gradYears.map((String value) {
          return DropdownMenuItem<String>(value: value, child: Text(value));
        }).toList(),
        onChanged: (newValue) => setState(() => _selectedGradYear = newValue),
        validator: (value) => value == null ? 'Please select a year' : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _cityController,
        decoration: const InputDecoration(labelText: 'City*', border: OutlineInputBorder()),
        validator: (value) => (value == null || value.isEmpty) ? 'This field is required' : null,
      ),
    ];
  }

  List<Widget> _buildPageThree() {
    return [
      DropdownButtonFormField<String>(
        value: _selectedRole,
        decoration: const InputDecoration(labelText: 'Target Role*', border: OutlineInputBorder()),
        items: _roles.map((String value) {
          return DropdownMenuItem<String>(value: value, child: Text(value, overflow: TextOverflow.ellipsis));
        }).toList(),
        onChanged: (newValue) => setState(() => _selectedRole = newValue),
        validator: (value) => value == null ? 'Please select a role' : null,
        isExpanded: true,
      ),
      if (_selectedRole == 'Other') ...[
        const SizedBox(height: 16),
        TextFormField(
          controller: _otherRoleController,
          decoration: const InputDecoration(labelText: 'Please specify other role*', border: OutlineInputBorder()),
          validator: (value) => (value == null || value.isEmpty) ? 'This field is required' : null,
        ),
      ],
      const SizedBox(height: 16),
      TextFormField(
        controller: _skillsController,
        decoration: const InputDecoration(labelText: 'Key Skills*', hintText: 'Comma-separated, e.g., Python, Flutter', border: OutlineInputBorder()),
        maxLines: 3,
        validator: (value) => (value == null || value.isEmpty) ? 'Please list your skills' : null,
      ),
    ];
  }
}