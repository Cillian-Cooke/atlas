import 'package:flutter/material.dart';
import '../popup_container.dart';
import '../../Services/autocomplete_service.dart';

class EditMapPopUpContent extends StatefulWidget {
  final String title;
  final String description;
  final List<String> items;
  final bool initialUnseen;
  final bool initialRogue;
  final void Function(Map<String, dynamic>) onConfigUpdated;

  const EditMapPopUpContent({
    super.key,
    required this.title,
    required this.description,
    required this.items,
    this.initialUnseen = true,
    this.initialRogue = true,
    required this.onConfigUpdated,
  });

  @override
  _EditMapPopUpContentState createState() => _EditMapPopUpContentState();
}

class _EditMapPopUpContentState extends State<EditMapPopUpContent> {
  bool isUnseen = true;
  bool isRogue = true;
  late List<String> items;
  
  final List<Color> labelColors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.purple,
    Colors.orange,
    Colors.teal,
    Colors.pink,
  ];

  @override
  void initState() {
    super.initState();
    items = List.from(widget.items);
    isUnseen = widget.initialUnseen;
    isRogue = widget.initialRogue;
  }

  void _showEditMapListDialog() {
    List<String> editableItems = List.from(items);
    TextEditingController controller = TextEditingController();
    final autocompleteService = AutocompleteService();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Edit List'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: editableItems.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text('${index + 1}: ${editableItems[index]}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setStateDialog(() {
                                editableItems.removeAt(index);
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildAutocompleteInput(
                    controller: controller,
                    autocompleteService: autocompleteService,
                    onItemAdded: (text) {
                      setStateDialog(() {
                        if (text.isNotEmpty && !editableItems.contains(text)) {
                          editableItems.add(text);
                          controller.clear();
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    items = editableItems;
                  });
                  // Close the inner edit dialog first, then notify the outer popup
                  Navigator.pop(context);
                  // Return configuration with items and toggles
                  widget.onConfigUpdated({
                    'items': items,
                    'isUnseen': isUnseen,
                    'isRogue': isRogue,
                  });
                },
                child: const Text('Save'),
              ),
            ],
          );
        });
      },
    );
  }

  /// Build autocomplete input widget
  Widget _buildAutocompleteInput({
    required TextEditingController controller,
    required AutocompleteService autocompleteService,
    required Function(String) onItemAdded,
  }) {
    return StatefulBuilder(
      builder: (context, setStateAutocomplete) {
        List<String> suggestions = [];
        bool showSuggestions = false;

        return Column(
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Add item (@username or #tag)',
                hintText: 'Type @ for users, # for tags',
                border: const OutlineInputBorder(),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          controller.clear();
                          setStateAutocomplete(() {
                            showSuggestions = false;
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) async {
                setStateAutocomplete(() {
                  showSuggestions = false;
                  suggestions = [];
                });

                // Detect @ or # and show autocomplete
                if (value.contains('@')) {
                  final lastAtIndex = value.lastIndexOf('@');
                  if (lastAtIndex != -1) {
                    final query = value.substring(lastAtIndex + 1);
                    if (query.isNotEmpty && query.length >= 1) {
                      final users = await autocompleteService.searchUsers(query);
                      setStateAutocomplete(() {
                        suggestions = users;
                        showSuggestions = suggestions.isNotEmpty;
                      });
                    }
                  }
                } else if (value.contains('#')) {
                  final lastHashIndex = value.lastIndexOf('#');
                  if (lastHashIndex != -1) {
                    final query = value.substring(lastHashIndex + 1);
                    if (query.isNotEmpty && query.length >= 1) {
                      final tags = await autocompleteService.searchTags(query);
                      setStateAutocomplete(() {
                        suggestions = tags;
                        showSuggestions = suggestions.isNotEmpty;
                      });
                    }
                  }
                }
              },
              onSubmitted: (value) {
                final text = value.trim();
                if (text.isNotEmpty) {
                  onItemAdded(text);
                  setStateAutocomplete(() {
                    showSuggestions = false;
                    suggestions = [];
                  });
                }
              },
            ),
            const SizedBox(height: 8),
            if (showSuggestions && suggestions.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                constraints: const BoxConstraints(maxHeight: 150),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: suggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = suggestions[index];
                    return ListTile(
                      dense: true,
                      title: Text(
                        controller.text.contains('@') ? '@$suggestion' : '#$suggestion',
                        style: const TextStyle(fontSize: 14),
                      ),
                      onTap: () {
                        onItemAdded(controller.text.contains('@') ? '@$suggestion' : '#$suggestion');
                        controller.clear();
                        setStateAutocomplete(() {
                          showSuggestions = false;
                          suggestions = [];
                        });
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final text = controller.text.trim();
                      if (text.isNotEmpty) {
                        onItemAdded(text);
                        setStateAutocomplete(() {
                          showSuggestions = false;
                          suggestions = [];
                        });
                      }
                    },
                    child: const Text('Add'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;

    return SizedBox(
      height: screen.height * 0.7,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center( 
            child: Text(
              widget.title,
              style: const TextStyle(
                fontSize: 35,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 10),

          Center(
            child: Container(
              height: screen.height*0.20,
              width: screen.height*0.20, 
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: const Color.fromARGB(255, 116, 116, 116),
                  width: 3,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Image.asset(
                  'assets/edit_previews/${items.length}_labels.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback if image doesn't exist
                    return Container(
                      color: const Color.fromARGB(255, 255, 255, 255),
                      child: Center(
                        child: Text(
                          '${items.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // List of items with index
          ...items.asMap().entries.map((entry) {
            int index = entry.key;
            String item = entry.value;
            Color circleColor = labelColors[index % labelColors.length];

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 10,
                      color: Colors.black12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      child: Row( 
                        children: [
                          Container(
                            margin: const EdgeInsets.all(5),
                            width: 25,
                            height: 25,
                            decoration: const BoxDecoration(
                              color: Color.fromARGB(255, 233, 245, 255),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child:Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          ),
                          Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Text(
                              item,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ]
                      )
                    ),
                    Container(
                      margin: const EdgeInsets.all(5),
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                        color: circleColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          TextButton.icon(
            onPressed: _showEditMapListDialog,
            icon: const Icon(Icons.edit),
            label: const Text('Edit List'),
          ),

          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 25,
                color: Colors.blue,
                icon: const Icon(Icons.info_outline),
                onPressed: () => showDialog(
                  context: context,
                  builder: (BuildContext context) => AlertDialog(
                    title: const Text('Unseen Posts Description'),
                    content: Text('These are posts that have appeared in your feed before, preventing you from seeing the same content more than once.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, 'OK'),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Only Unseen Posts',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Switch(
                value: isUnseen,
                activeThumbColor: const Color.fromARGB(255, 54, 200, 244),
                onChanged: (bool value) {
                  setState(() {
                    isUnseen = value;
                  });
                },
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 25,
                color: Colors.blue,
                icon: const Icon(Icons.info_outline),
                onPressed: () => showDialog(
                  context: context,
                  builder: (BuildContext context) => AlertDialog(
                    title: const Text('Rogue Posts Description'),
                    content: Text('These are randomized posts with a monochrome color scheme to add visual interest and excitement to your feed.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, 'OK'),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Rogue Posts',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Switch(
                value: isRogue,
                activeThumbColor: const Color.fromARGB(255, 54, 200, 244),
                onChanged: (bool value) {
                  setState(() {
                    isRogue = value;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// POPUP OPEN FUNCTION
Future<Map<String, dynamic>?> showEditMapPagePopUp(
  BuildContext context,
  String title,
  String description,
  List<String> items, {
  bool initialUnseen = true,
  bool initialRogue = true,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (context) {
      return PopupContainer(
        child: EditMapPopUpContent(
          title: title,
          description: description,
          items: items,
          initialUnseen: initialUnseen,
          initialRogue: initialRogue,
          onConfigUpdated: (config) {
            Navigator.pop(context, config);
          },
        ),
      );
    },
  );
}