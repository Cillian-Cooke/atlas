import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:atlas/Widgets/bottom_bar.dart';
import '../Services/auth_service.dart';
import 'registration_page.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginScreen({
    Key? key,
    required this.onLoginSuccess,
  }) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _authService.signInWithGoogle();

      if (user != null) {
        // Check if user has completed their profile
        final hasProfile = await _authService.hasCompletedProfile();

        if (mounted) {
          if (hasProfile) {
            // User has completed profile, go to main app
            widget.onLoginSuccess();
          } else {
            // User needs to complete profile, show registration screen
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => RegistrationScreen(
                  onRegistrationComplete: widget.onLoginSuccess,
                ),
              ),
            );
          }
        }
      } else {
        setState(() => _errorMessage = 'Sign in was cancelled');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _skipForTesting() {
    // Navigate directly to main app for web testing
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const MyNavigatorBar(title: 'Navigation Bar'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  const SizedBox(height: 60),
                  // App logo/title
                  Text(
                    'Atlas',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Connect, Share, Explore',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              Column(
                children: [
                  // Error message
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  // Google Sign In Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 32,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!_isLoading)
                          const Icon(Icons.login, size: 20),
                        if (!_isLoading) const SizedBox(width: 12),
                        _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Sign in with Google',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Secure login with your Google account',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  // Web-only skip button for testing
                  if (kIsWeb)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: TextButton(
                        onPressed: _skipForTesting,
                        child: Text(
                          'Skip for Testing (Web Only)',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.grey[600],
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
