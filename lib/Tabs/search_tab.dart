import 'package:flutter/material.dart';
import '../Pages/search_page.dart';

class SearchTab extends StatelessWidget {
  const SearchTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SearchPage(title: 'Search');
  }
}