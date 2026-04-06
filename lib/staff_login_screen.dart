import 'dart:ui'; // Required for BackdropFilter (Blur effect)
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StaffLoginScreen extends StatefulWidget {
  const StaffLoginScreen({super.key});

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  // Firebase Login Logic
  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;

      // Update Staff availability in Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userCred.user!.uid)
          .get();

      if (userDoc.exists && userDoc['role'] == 'staff') {
        await FirebaseFirestore.instance
            .collection('Staff')
            .doc(userCred.user!.uid)
            .set({
          'isAvailable': true,
          'lastLogin': FieldValue.serverTimestamp(),
          'name': userDoc['name'] ?? 'Staff Member',
        }, SetOptions(merge: true));
      }
      // Note: AuthGate in main.dart will automatically redirect upon success
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login Failed: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Background Gradient & Decorative Elements
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFDBEAFE), Color(0xFFBFDBFE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Optional: Decorative circle
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: .2),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // 2. The Glassmorphic Card
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    width: 400,
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .8),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: .5)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon Header
                        Container(
                          width: 60, height: 60,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.health_and_safety, color: Colors.white, size: 30),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          "Login",
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                        ),
                        const Text(
                          "Welcome back to HealthCare Portal",
                          style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                        ),
                        const SizedBox(height: 32),

                        // Email Field
                        _buildTextField(
                          controller: _emailController,
                          hint: "Email Address",
                          icon: Icons.email_outlined,
                        ),
                        const SizedBox(height: 16),

                        // Password Field
                        _buildTextField(
                          controller: _passwordController,
                          hint: "Password",
                          icon: Icons.lock_outline,
                          isPassword: true,
                          toggleVisibility: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                          obscureText: !_isPasswordVisible,
                        ),

                        const SizedBox(height: 32),

                        // Login Button
                        _isLoading
                            ? const CircularProgressIndicator()
                            : SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text(
                                      "Continue",
                                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
        ],
      ),
    );
  }

  // Helper UI for TextFields
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? toggleVisibility,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.blueAccent, size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility, size: 20),
                onPressed: toggleVisibility,
              )
            : null,
        filled: true,
        fillColor: Colors.white.withValues(alpha: .9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
      ),
    );
  }
}