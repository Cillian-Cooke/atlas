import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../popup_container.dart';

class SettingsPopUp extends StatefulWidget {

  const SettingsPopUp({
    super.key,
  });

  @override
  State<SettingsPopUp> createState() => _SettingsPopUpState();
}

class _SettingsPopUpState extends State<SettingsPopUp> {
  bool? _darkMode;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDarkMode();
  }

  Future<void> _loadDarkMode() async {
    // TODO: Replace with actual user ID logic
    final userId = "I8PwtNA3QTEt44rxH8jN";
    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final data = doc.data();
    setState(() {
      _darkMode = (data != null && data['darkMode'] is bool) ? data['darkMode'] : false;
      _isLoading = false;
    });
  }

  Future<void> _updateDarkMode(bool value) async {
    // TODO: Replace with actual user ID logic
    final userId = "I8PwtNA3QTEt44rxH8jN";
    await FirebaseFirestore.instance.collection('users').doc(userId).update({'darkMode': value});
    setState(() {
      _darkMode = value;
    });
  }


  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: _isLoading
            ? CircularProgressIndicator()
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Dark Mode'),
                  Switch(
                    value: _darkMode ?? false,
                    onChanged: (val) => _updateDarkMode(val),
                  ),
                ],
              ),
      ),
    );
  }
}

Future<void> showSettingsPopUp(BuildContext context) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (context) {
      return PopupContainer(
        child: SettingsPopUp(),
      );
    },
  );
}
