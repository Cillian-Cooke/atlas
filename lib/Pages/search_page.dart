import 'package:flutter/material.dart';
import '../Map_And_Bubbles/map_logic.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          TiledMapViewer(
            backgroundAsset: Theme.of(context).brightness == Brightness.dark
                ? 'assets/background_dark.png' 
                : 'assets/background_light.png',
          ),
          Center(
            child: Container(
              height: 300,
              width: 300,
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color.fromARGB(255, 40, 40, 40)
                    : const Color.fromARGB(255, 255, 255, 255),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black.withOpacity(0.5)
                        : const Color.fromARGB(255, 87, 87, 87),
                    blurRadius: 7,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        "Search Bar",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 30,
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        iconSize: 25,
                        color: Colors.blue,
                        icon: const Icon(Icons.info_outline),
                        onPressed: () => showDialog<String>(
                          context: context,
                          builder: (BuildContext context) => AlertDialog(
                            backgroundColor: Theme.of(context).brightness == Brightness.dark
                              ? const Color.fromARGB(255, 40, 40, 40)
                                : Colors.white,
                            title: Text(
                              'Search Definition',
                              style: TextStyle(
                                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                              ),
                            ),
                            content: Text(
                              'This search algorithm is almost non-existent and therefore not biased towards a particular creator, business or tag.',
                              style: TextStyle(
                                color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () => Navigator.pop(context, 'OK'),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  SearchBar(
                    hintText: "#tags, @users and ?other....",
                    hintStyle: WidgetStateProperty.all(
                      TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white54 
                            : Colors.black54,
                      ),
                    ),
                    backgroundColor: WidgetStateProperty.all(
                      Theme.of(context).brightness == Brightness.dark
                          ? const Color.fromARGB(255, 60, 60, 60)
                          : Colors.white,
                    ),
                    textStyle: WidgetStateProperty.all(
                      TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                      ),
                    ),
                    onChanged: (value) {},
                  ),
                ],
              ),
            ),
          )
        ],
      )
    );
  }
}