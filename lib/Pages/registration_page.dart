import 'package:flutter/material.dart';
import '../Services/auth_service.dart';

class RegistrationScreen extends StatefulWidget {
  final VoidCallback onRegistrationComplete;

  const RegistrationScreen({
    Key? key,
    required this.onRegistrationComplete,
  }) : super(key: key);

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _authService = AuthService();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _usernameAvailable = false;
  bool _checkingUsername = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  /// Check if username is available as user types
  Future<void> _checkUsernameAvailability(String username) async {
    if (username.isEmpty) {
      setState(() {
        _usernameAvailable = false;
        _checkingUsername = false;
      });
      return;
    }

    // Only alphanumeric and underscore allowed
    if (!RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(username)) {
      setState(() {
        _usernameAvailable = false;
        _checkingUsername = false;
      });
      return;
    }

    setState(() => _checkingUsername = true);

    final available = await _authService.isUsernameAvailable(username);
    setState(() {
      _usernameAvailable = available;
      _checkingUsername = false;
    });
  }

  /// Complete registration
  Future<void> _completeRegistration() async {
    if (_usernameController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter a username');
      return;
    }

    if (!_usernameAvailable) {
      setState(() => _errorMessage = 'Username is not available');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await _authService.updateUserProfile(
        username: _usernameController.text.trim(),
        bio: _bioController.text.trim(),
      );

      if (success) {
        setState(() => _errorMessage = null);
        widget.onRegistrationComplete();
      } else {
        setState(() => _errorMessage = 'Failed to update profile. Try again.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Text(
              'Welcome to Atlas!',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Let\'s set up your profile',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // Username field
            Text(
              'Username',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _usernameController,
              onChanged: _checkUsernameAvailability,
              decoration: InputDecoration(
                hintText: 'Enter your username (3-20 characters)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.person),
                suffixIcon: _checkingUsername
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _usernameController.text.isNotEmpty
                        ? Icon(
                            _usernameAvailable ? Icons.check : Icons.close,
                            color: _usernameAvailable ? Colors.green : Colors.red,
                          )
                        : null,
              ),
            ),
            if (_usernameController.text.isNotEmpty && !_usernameAvailable)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _checkingUsername
                      ? 'Checking availability...'
                      : 'Username not available or invalid (use only letters, numbers, underscore)',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            const SizedBox(height: 24),

            // Bio field
            Text(
              'Bio (Optional)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bioController,
              maxLines: 3,
              maxLength: 150,
              decoration: InputDecoration(
                hintText: 'Tell us about yourself...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.info),
              ),
            ),
            const SizedBox(height: 24),

            // Error message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            const SizedBox(height: 24),

            // Submit button
            ElevatedButton(
              onPressed: _isLoading || !_usernameAvailable
                  ? null
                  : _completeRegistration,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Complete Profile',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
