import 'package:flutter/material.dart';
import '../Pages/competition_page.dart';
import '../PopUps/edit/filter_comp_popup.dart';
import '../PopUps/search_popup.dart';
import '../Widgets/icon_button.dart';
import '../PopUps/edit/create_competition_popup.dart';

class CompetitionTab extends StatefulWidget {
  const CompetitionTab({super.key});

  @override
  State<CompetitionTab> createState() => _CompetitionTabState();
}

class _CompetitionTabState extends State<CompetitionTab> {
  bool isVisable = true;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main page content
        CompetitionPage(title: 'Competitions', visibility: isVisable),
        
        // ---------- COMPETITIONS VISIBILITY BUTTON ----------
        Positioned(
          bottom: 65,
          right: 8,
            child: IconButtonWidget(
              icon: isVisable ? Icons.visibility_outlined : Icons.visibility_off,
              onPressed: () {
                setState(() {
                  isVisable = !isVisable;
                });
              },
              buttonSize: 70,
            ),
          ),

        // ---------- FILTER BUTTON (comp) ----------
        Positioned(
          top: 50,
          right: 8,
          child: IconButtonWidget(
            icon: Icons.filter_alt,
            onPressed: () {
              showFilterCompPopUp(context, 'This is a detailed description for item.');
            },
            buttonSize: 70,
          ),
        ),
        
        // ------------ search button ---------
        Positioned(
          top: 120,
          right: 8,
          child: IconButtonWidget(
            icon: Icons.search,
            onPressed: () {
              showSearchPopUp(context, 'This is a detailed description for item.');
            },
            buttonSize: 70,
          ),
        ),

        // ------------ search button ---------
        Positioned(
          top: 190,
          right: 8,
          child: IconButtonWidget(
            icon: Icons.add,
            onPressed: () {
              showCreateCompetitionPopUp(context);
            },
            buttonSize: 70,
          ),
        ),
      ],
    );
  }
}