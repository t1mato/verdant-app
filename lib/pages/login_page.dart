import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback toggleScreen;
  const LoginPage({super.key, required this.toggleScreen});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController(); // Can be email or username
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isUsernameLogin = true; // Toggle between username and email login

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Login field validator
  String? _validateLogin(String? value) {
    if (value == null || value.isEmpty) {
      return _isUsernameLogin ? 'Username is required' : 'Email is required';
    }

    if (!_isUsernameLogin) {
      bool emailValid = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value);
      if (!emailValid) {
        return 'Enter a valid email';
      }
    }

    return null;
  }

  // Password validator
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }

    return null;
  }

  // Get user email from username
  Future<String?> _getEmailFromUsername(String username) async {
    print('DEBUG: _getEmailFromUsername called with username: $username');
    try {
      // Simplified query without orderBy
      print('DEBUG: About to execute Firestore query');
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .get();
      print('DEBUG: Query executed successfully, found ${querySnapshot.docs.length} documents');

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.get('email') as String?;
      }
      return null;
    } catch (e) {
      print('DEBUG: Error getting email from username: $e');
      return null;
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String email = _loginController.text.trim();

      // If using username, convert to email
      if (_isUsernameLogin) {
        final userEmail = await _getEmailFromUsername(email);
        if (userEmail == null) {
          _showErrorSnackbar('User not found');
          setState(() => _isLoading = false);
          return;
        }
        email = userEmail;
      }

      // Sign in with email and password
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      _showErrorSnackbar(e.message ?? 'Sign in failed');
    } catch (e) {
      _showErrorSnackbar('An unexpected error occurred');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sign In',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Logo/Icon
                  const Icon(
                    Icons.account_balance_wallet,
                    size: 80,
                    color: Color(0xFF43B048),
                  ),
                  const SizedBox(height: 32),

                  // Login Method Toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text('Username'),
                        selected: _isUsernameLogin,
                        onSelected: (selected) {
                          setState(() {
                            _isUsernameLogin = selected;
                          });
                        },
                      ),
                      const SizedBox(width: 16),
                      ChoiceChip(
                        label: const Text('Email'),
                        selected: !_isUsernameLogin,
                        onSelected: (selected) {
                          setState(() {
                            _isUsernameLogin = !selected;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Username/Email Field
                  TextFormField(
                    controller: _loginController,
                    decoration: InputDecoration(
                      labelText: _isUsernameLogin ? 'Username' : 'Email',
                      prefixIcon: Icon(_isUsernameLogin ? Icons.person : Icons.email),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: _isUsernameLogin
                        ? TextInputType.text
                        : TextInputType.emailAddress,
                    validator: _validateLogin,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: _validatePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _signIn(),
                  ),
                  const SizedBox(height: 24),

                  // Sign In Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _signIn,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: const Color(0xFF43B048),
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Text('Sign In', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 16),

                  // Sign Up Link
                  TextButton(
                    onPressed: widget.toggleScreen,
                    child: const Text("Don't have an account? Sign up here"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}