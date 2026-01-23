import '../Content_Feed/feed.dart';
import 'package:flutter/material.dart';
import '../Tabs/search_tab.dart';
import '../Tabs/home_tab.dart';
import '../Tabs/camera_tab.dart';
import '../Tabs/competition_tab.dart';
import '../Tabs/groups_tab.dart';

class MyNavigatorBar extends StatefulWidget {
  const MyNavigatorBar({super.key, required this.title});

  final String title;

  @override
  State<MyNavigatorBar> createState() => _MyNavigatorBarState();
}

class _MyNavigatorBarState extends State<MyNavigatorBar> {
  int _selectedIndex = 1;
  
  // Shared state for captured bubbles
  final ValueNotifier<List<String>> capturedBubbles = ValueNotifier([]);

  // Navigator keys for each tab (now including feed tab at index 5)
  final Map<int, GlobalKey<NavigatorState>> _navigatorKeys = {
    0: GlobalKey<NavigatorState>(),
    1: GlobalKey<NavigatorState>(),
    2: GlobalKey<NavigatorState>(),
    3: GlobalKey<NavigatorState>(),
    4: GlobalKey<NavigatorState>(),
    5: GlobalKey<NavigatorState>(), 
  };

  // Build the navigator for each tab
  Widget _buildNavigator(int index) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (routeSettings) {
        return MaterialPageRoute(
          builder: (context) => _getTabWidget(index),
        );
      },
    );
  }

  // Get the tab widget for each index
  Widget _getTabWidget(int index) {
    switch (index) {
      case 0:
        return SearchTab();
      case 1:
        return HomeTab(onCaptureBubbles: (bubbles) {
          capturedBubbles.value = List.from(bubbles);
          // Switch to feed tab (index 5)
          setState(() => _selectedIndex = 5);
        });
      case 2:
        return CameraTab();
      case 3:
        return GroupsTab(onCaptureBubbles: (bubbles) {
          print('GroupsTab onCaptureBubbles called with: $bubbles');
          capturedBubbles.value = List.from(bubbles);
          // Switch to feed tab (index 5)
          setState(() => _selectedIndex = 5);
        });
      case 4:
        return CompetitionTab();
      case 5:
        return FeedTab(capturedBubbles: capturedBubbles);
      default:
        return SearchTab();
    }
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) {
      // If tapping the same tab, pop to root of that tab's navigator
      _navigatorKeys[index]!.currentState?.popUntil((route) => route.isFirst);
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  // Handle back button press
  Future<bool> _onWillPop() async {
    final isFirstRouteInCurrentTab =
        !await _navigatorKeys[_selectedIndex]!.currentState!.maybePop();
    
    if (isFirstRouteInCurrentTab) {
      // If on first route, check if not on home tab
      if (_selectedIndex != 1) {
        // Switch to home tab
        setState(() => _selectedIndex = 1);
        return false;
      }
    }
    
    return isFirstRouteInCurrentTab;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: List.generate(6, (index) => _buildNavigator(index)), 
        ),
        
        // ---------- BOTTOM NAVIGATION BAR ----------
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color.fromARGB(255, 30, 30, 30) : Colors.white,
            boxShadow: [
              BoxShadow(
                blurRadius: 10,
                color: isDark ? Colors.black45 : Colors.black12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              backgroundColor: isDark ? const Color.fromARGB(255, 30, 30, 30) : Colors.white,

              currentIndex: _selectedIndex == 5 ? 1 : _selectedIndex,

              selectedItemColor: _selectedIndex == 5 ? Colors.grey : (isDark ? Colors.white : Colors.black),
              unselectedItemColor: Colors.grey,

              showSelectedLabels: _selectedIndex != 5, 
              showUnselectedLabels: false,              

              onTap: _onItemTapped,

              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline_outlined), label: 'Create'),
                BottomNavigationBarItem(icon: Icon(Icons.diversity_3), label: 'Groups'),
                BottomNavigationBarItem(icon: Icon(Icons.leaderboard), label: 'Comp'),
              ],
            )
          ),
        ),
      ),
    );
  }
}