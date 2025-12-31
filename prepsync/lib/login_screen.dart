// lib/login_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepsync/create_profile_screen.dart';
import 'package:prepsync/dashboard_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:simple_animations/simple_animations.dart';

// 1. IMPORT YOUR NEW API_CONFIG.DART FILE
import 'package:prepsync/api_config.dart'; 

enum AuthMode { signup, login }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  AuthMode _authMode = AuthMode.login;
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _forgotPasswordController = TextEditingController();
  
  void _navigateOnSuccess(int userId, bool profileExists, {String? name}) {
    final currentContext = context;
    if (!mounted) return;
    Navigator.pushReplacement(
      currentContext,
      MaterialPageRoute(
        builder: (context) => profileExists
            ? DashboardScreen(userId: userId)
            : CreateProfileScreen(userId: userId, initialName: name),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState?.save();
    setState(() => _isLoading = true);
    
    // 2. USE THE 'baseUrl' FROM YOUR CONFIG FILE
    // No more hard-coded IP!
    String endpoint = _authMode == AuthMode.login ? '/login' : '/register';
    final url = '$baseUrl$endpoint';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': _emailController.text,
          'password': _passwordController.text,
        }),
      );
      
      final responseData = json.decode(response.body);
      
      if (!mounted) return;

      if (response.statusCode >= 400) {
        _showSnackBar(responseData['message'], isError: true);
      } else {
        if (_authMode == AuthMode.login) {
          _navigateOnSuccess(responseData['user_id'], responseData['profile_exists']);
        } else {
          _showSnackBar('Registration successful! Please log in.', isError: false);
          _switchAuthMode();
        }
      }
    } catch (e) {
      _showSnackBar('Could not connect to the server. Is the backend running?', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      
      // 2. USE THE 'baseUrl' FROM YOUR CONFIG FILE
      const url = '$baseUrl/google-auth'; 
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': googleUser.email}),
      );
      
      final responseData = json.decode(response.body);
      if (!mounted) return;

      if (response.statusCode == 200) {
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
        
        _navigateOnSuccess(
          responseData['user_id'], 
          responseData['profile_exists'],
          name: googleUser.displayName,
        );
      } else {
         _showSnackBar(responseData['message'], isError: true);
      }
    } catch (e) {
      _showSnackBar('Google Sign-In failed. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _forgotPassword() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: TextField(
          controller: _forgotPasswordController,
          decoration: const InputDecoration(labelText: 'Enter your email'),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            child: const Text('Submit'),
            onPressed: () async {
              final dialogContext = ctx;
              // 2. USE THE 'baseUrl' FROM YOUR CONFIG FILE
              await http.post(
                Uri.parse('$baseUrl/forgot-password'), // <-- FIXED
                headers: {'Content-Type': 'application/json'},
                body: json.encode({'email': _forgotPasswordController.text}),
              );
              if (!mounted) return;
              Navigator.of(dialogContext).pop();
              _showSnackBar('If an account exists, a reset link has been sent.', isError: false);
            },
          )
        ],
      ),
    );
  }

  void _switchAuthMode() {
    setState(() {
      _authMode = _authMode == AuthMode.login ? AuthMode.signup : AuthMode.login;
    });
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    // --- ALL THE UI CODE BELOW IS UNCHANGED ---
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF00A79D), Color(0xFF43C6AC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: PlayAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 50 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    const Icon(Icons.psychology_outlined, color: Colors.white, size: 60),
                    const SizedBox(height: 10),
                    Text(
                      'PrepSync',
                      style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    Text(
                      'Unlock Your Future.',
                      style: GoogleFonts.poppins(fontSize: 16, color: const Color.fromRGBO(255, 255, 255, 0.8)),
                    ),
                    const SizedBox(height: 30),
                    ClipPath(
                      clipper: TopWaveClipper(),
                      child: Container(
                        color: Colors.white,
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(24, 50, 24, 24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _emailController,
                                decoration: _buildInputDecoration(hint: 'Email', icon: Icons.email_outlined),
                                validator: (value) {
                                  if (value == null || !value.contains('@')) return 'Please enter a valid email.';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: !_isPasswordVisible,
                                decoration: _buildInputDecoration(
                                  hint: 'Password',
                                  icon: Icons.lock_outline,
                                ).copyWith(
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isPasswordVisible = !_isPasswordVisible;
                                      });
                                    },
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.length < 4) return 'Password must be at least 4 characters.';
                                  return null;
                                },
                              ),
                              if (_authMode == AuthMode.signup) ...[
                                const SizedBox(height: 20),
                                TextFormField(
                                  obscureText: true,
                                  decoration: _buildInputDecoration(hint: 'Confirm Password', icon: Icons.lock_outline),
                                  validator: (value) {
                                    if (value != _passwordController.text) return 'Passwords do not match!';
                                    return null;
                                  },
                                ),
                              ],
                              if (_authMode == AuthMode.login)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _forgotPassword,
                                    child: const Text('Forgot Password?'),
                                  ),
                                ),
                              const SizedBox(height: 20),
                              if (_isLoading)
                                const Center(child: CircularProgressIndicator())
                              else
                                _buildLoginButton(),
                              TextButton(
                                onPressed: _switchAuthMode,
                                child: Text(_authMode == AuthMode.login ? 'Don\'t have an account? Sign Up' : 'Already have an account? Login'),
                              ),
                              const SizedBox(height: 20),
                                Row(
                                children: <Widget>[
                                  const Expanded(child: Divider()),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                    child: Text("OR", style: TextStyle(color: Colors.grey.shade600)),
                                  ),
                                  const Expanded(child: Divider()),
                                ],
                              ),
                              const SizedBox(height: 20),
                              _buildGoogleSignInButton(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.grey),
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildLoginButton() {
    return GestureDetector(
      onTap: _submit,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(colors: [Color(0xFF00A79D), Color(0xFF43C6AC)]),
        ),
        child: Center(
          child: Text(
            _authMode == AuthMode.login ? 'LOGIN' : 'SIGN UP',
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleSignInButton() {
    return Center(
      child: OutlinedButton.icon(
        icon: const FaIcon(FontAwesomeIcons.google, color: Colors.red),
        label: Text('Sign in with Google', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.black87)),
        onPressed: _signInWithGoogle,
        style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            side: BorderSide(color: Colors.grey.shade300)
        ),
      ),
    );
  }
}

class TopWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, 20);
    var firstControlPoint = Offset(size.width / 4, 0);
    var firstEndPoint = Offset(size.width / 2.2, 25);
    path.quadraticBezierTo(firstControlPoint.dx, firstControlPoint.dy, firstEndPoint.dx, firstEndPoint.dy);
    var secondControlPoint = Offset(size.width * 3 / 4, 50);
    var secondEndPoint = Offset(size.width, 20);
    path.quadraticBezierTo(secondControlPoint.dx, secondControlPoint.dy, secondEndPoint.dx, secondEndPoint.dy);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}