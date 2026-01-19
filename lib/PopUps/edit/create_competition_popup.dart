import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../popup_container.dart';

class CreateCompetitionPopUp extends StatefulWidget {
  const CreateCompetitionPopUp({super.key});

  @override
  State<CreateCompetitionPopUp> createState() => _CreateCompetitionPopUpState();
}

class _CreateCompetitionPopUpState extends State<CreateCompetitionPopUp> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Form controllers
  final _titleController = TextEditingController();
  final _usernameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sizeController = TextEditingController();
  final _prizeController = TextEditingController();

  // Date/Time pickers
  DateTime? _startTime;
  DateTime? _endTime;

  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _usernameController.dispose();
    _descriptionController.dispose();
    _sizeController.dispose();
    _prizeController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime(BuildContext context, bool isStartTime) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null && context.mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        final DateTime combinedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        setState(() {
          if (isStartTime) {
            _startTime = combinedDateTime;
          } else {
            _endTime = combinedDateTime;
          }
        });
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _createCompetition() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both start and end times'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_endTime!.isBefore(_startTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End time must be after start time'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Parse size and prize with validation
      final size = int.tryParse(_sizeController.text.trim());
      final prize = double.tryParse(_prizeController.text.trim());

      if (size == null || prize == null) {
        throw Exception('Invalid size or prize value');
      }

      // Create competition document
      await _firestore.collection('competitions').add({
        'title': _titleController.text.trim(),
        'username': _usernameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'size': size,
        'prize': prize,
        'startTime': Timestamp.fromDate(_startTime!),
        'endTime': Timestamp.fromDate(_endTime!),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        Navigator.of(context).pop(true); // Return true on success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Competition created successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error creating competition: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating competition: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupContainer(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(
                      Icons.emoji_events,
                      size: 32,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Create Competition',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 30),

                // Title Field
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Competition Title *',
                    hintText: 'e.g., Smosh Fan Art',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Username Field
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username *',
                    hintText: 'Your username',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a username';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Description Field
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description *',
                    hintText: 'Describe your competition...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Size and Prize in a Row
                Row(
                  children: [
                    // Size Field
                    Expanded(
                      child: TextFormField(
                        controller: _sizeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Size *',
                          hintText: '100',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.people),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          final size = int.tryParse(value);
                          if (size == null || size <= 0) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Prize Field
                    Expanded(
                      child: TextFormField(
                        controller: _prizeController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Prize *',
                          hintText: '20',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.diamond),
                          suffixText: '£',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          final prize = double.tryParse(value);
                          if (prize == null || prize < 0) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Date/Time Section Header
                const Text(
                  'Competition Schedule',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Start Time Picker
                InkWell(
                  onTap: () => _selectDateTime(context, true),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _startTime == null ? Colors.grey[300]! : Colors.blue,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          color: _startTime == null ? Colors.grey : Colors.blue,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Start Time *',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _startTime == null
                                    ? 'Tap to select'
                                    : _formatDateTime(_startTime!),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: _startTime == null ? FontWeight.normal : FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.calendar_today, color: Colors.blue),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // End Time Picker
                InkWell(
                  onTap: () => _selectDateTime(context, false),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _endTime == null ? Colors.grey[300]! : Colors.orange,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.alarm,
                          color: _endTime == null ? Colors.grey : Colors.orange,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'End Time *',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _endTime == null
                                    ? 'Tap to select'
                                    : _formatDateTime(_endTime!),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: _endTime == null ? FontWeight.normal : FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.calendar_today, color: Colors.orange),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Create Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _createCompetition,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      disabledBackgroundColor: Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.emoji_events,
                            color: Colors.white,
                          ),
                    label: Text(
                      _isSubmitting ? 'Creating...' : 'Create Competition',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool?> showCreateCompetitionPopUp(BuildContext context) async {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const CreateCompetitionPopUp(),
  );
}