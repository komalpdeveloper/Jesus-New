import 'package:flutter/material.dart';
import 'package:clientapp/features/store/presentation/store_home.dart';
import 'package:clientapp/features/store/presentation/shop_page.dart';
import 'package:clientapp/features/store/presentation/widgets/store_bottom_nav_bar.dart';

class StoreShellPage extends StatefulWidget {
  const StoreShellPage({super.key});

  @override
  State<StoreShellPage> createState() => _StoreShellPageState();
}

class _StoreShellPageState extends State<StoreShellPage> {
  int _index = 0; // 0 Home, 1 Shop, 2 Categories (sheet), 3 Cart (handled upstream)
  final GlobalKey _cartKey = GlobalKey();

  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      StoreHomePage(cartKey: _cartKey, embed: true),
      ShopPage(cartKey: _cartKey, embed: true),
    ];
  }

  @override
  Widget build(BuildContext context) {
    print('StoreShell build - current _index: $_index');
    return Scaffold(
      backgroundColor: const Color(0xFF130E0A),
      body: IndexedStack(
        index: _index,
        children: _tabs,
      ),
      bottomNavigationBar: StoreBottomNavBar(
        currentIndex: _index,
        cartKey: _cartKey,
        onTap: (i) {
          print('🔥 StoreShell onTap called with index: $i, current _index: $_index, tabs.length: ${_tabs.length}');
          setState(() {
            print('🔥 Inside setState, changing _index from $_index to $i');
            _index = i;
          });
          print('🔥 After setState, _index is now: $_index');
        },
      ),
    );
  }
}
