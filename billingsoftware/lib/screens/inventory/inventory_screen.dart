import 'package:flutter/material.dart';
import '../../widgets/common.dart';
import 'store_screen.dart';
import 'shop_screen.dart';
import 'book_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    body: Column(children: [
      Container(
        color: AppColors.primary,
        child: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2), text: 'Store'),
            Tab(icon: Icon(Icons.checkroom), text: 'Uniform / Shop'),
            Tab(icon: Icon(Icons.menu_book), text: 'Books / Stationery'),
          ],
        ),
      ),
      Expanded(child: TabBarView(controller: _tabs, children: const [
        StoreScreen(),
        ShopScreen(),
        BookScreen(),
      ])),
    ]),
  );
}




