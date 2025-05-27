import 'package:flutter/material.dart';
import 'package:mauzo/ui/screens/cart_screen.dart';
import 'package:mauzo/ui/screens/sale/add_sale_screen.dart';

import 'edit_sale.screen.dart';

class DualScreenAppInvoice extends StatelessWidget {
  final UserData? userData;
  const DualScreenAppInvoice({Key? key, this.userData}) : super(key: key);
  @override
  Widget build(BuildContext context) {

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;

    return Scaffold(
      appBar: null,
      body: isTablet ? TabletViewInvoice() : AddSaleScreen(
          userData:
          UserData('invoice'))
    );
  }
}

class TabletViewInvoice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Screen 1 on the left
        Expanded(
          flex: 1, // Adjust flex to control space distribution
          child:AddSaleScreen(
              userData:
              UserData('invoice'))
        ),
        VerticalDivider(width: 1, color: Colors.grey),
        // Screen 2 on the right
        Expanded(
          flex: 1,
          child: CartScreen(
              userData:
              UserData('invoice'))
        ),
      ],
    );
  }
}

