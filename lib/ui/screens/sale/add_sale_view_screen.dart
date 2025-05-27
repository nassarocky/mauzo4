import 'package:flutter/material.dart';
import 'package:mauzo/ui/screens/cart_screen.dart';
import 'package:mauzo/ui/screens/sale/add_sale_screen.dart';

import 'edit_sale.screen.dart';

class DualScreenApp extends StatelessWidget {
  final UserData? userData;
  const DualScreenApp({Key? key, this.userData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Treat web as tablet layout based on screen size
    final screenWidth = MediaQuery.of(context).size.width;
    final isTabletOrWeb = screenWidth >= 600;

    return Scaffold(
      appBar: null,
      body: isTabletOrWeb ? TabletView() : AddSaleScreen(),
    );
  }
}

class TabletView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Screen 1 on the left
        Expanded(
          flex: 1, // Adjust flex to control space distribution
          child: AddSaleScreen(),
        ),
        VerticalDivider(width: 1, color: Colors.grey),
        // Screen 2 on the right
        Expanded(
          flex: 1,
          child: CartScreen(),
        ),
      ],
    );
  }
}
