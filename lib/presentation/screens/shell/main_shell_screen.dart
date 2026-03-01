import 'package:flutter/material.dart';

import '../about/about_me_screen.dart';
import '../news/news_sentiment_screen.dart';
import '../stock_list/stock_list_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _selectedIndex = 0;
  final Set<int> _loadedTabs = <int>{0};

  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return const StockListScreen(showScaffold: false);
      case 1:
        return const NewsSentimentScreen(showScaffold: false);
      case 2:
      default:
        return const AboutMeScreen(showScaffold: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: List<Widget>.generate(3, (index) {
          if (!_loadedTabs.contains(index)) {
            return const SizedBox.shrink();
          }
          return _buildScreen(index);
        }),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
            _loadedTabs.add(index);
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.newspaper_outlined),
            selectedIcon: Icon(Icons.newspaper),
            label: 'News',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Me',
          ),
        ],
      ),
    );
  }
}
