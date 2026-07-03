import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'state/state_manager.dart';
import 'screens/dashboard_tab.dart';
import 'screens/groups_tab.dart';
import 'screens/friends_tab.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => StateManager(),
      child: const SplitWiseApp(),
    ),
  );
}

class SplitWiseApp extends StatelessWidget {
  const SplitWiseApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Splitwise App Clone',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: const Color(0xFF0D9488),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0D9488),
          secondary: Color(0xFF14B8A6),
          background: Color(0xFF0F172A),
          surface: Color(0xFF1E293B),
        ),
        useMaterial3: true,
      ),
      home: const MainScaffold(),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({Key? key}) : super(key: key);

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const DashboardTab(),
    const GroupsTab(),
    const FriendsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<StateManager>(context);
    final members = state.members;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'SplitWise Premium',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
            ),
          ],
        ),
        actions: [
          // User switcher dropdown
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: state.currentUserId,
                dropdownColor: const Color(0xFF1E293B),
                icon: const Icon(Icons.swap_horiz, color: Color(0xFF14B8A6)),
                selectedItemBuilder: (BuildContext context) {
                  return members.map<Widget>((m) {
                    return Center(
                      child: Text(
                        m.name == 'You' ? 'You' : m.name.split(' ')[0],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }).toList();
                },
                items: members.map((m) {
                  return DropdownMenuItem(
                    value: m.id,
                    child: Text(
                      m.name == 'You' ? 'You' : m.name,
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    state.setCurrentUser(val);
                  }
                },
              ),
            ),
          ),
        ],
      ),
      body: _tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        backgroundColor: const Color(0xFF1E293B),
        selectedItemColor: const Color(0xFF14B8A6),
        unselectedItemColor: const Color(0xFF94A3B8),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group_outlined),
            activeIcon: Icon(Icons.group),
            label: 'Groups',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Friends',
          ),
        ],
      ),
    );
  }
}
