import 'package:flutter/material.dart';

import '../../../utils/app_navigation.dart';
import '../../../utils/constants.dart';

class DrawerTile extends StatelessWidget {
  const DrawerTile({
    Key? key,
    required this.route,
    required this.title,
    required this.icon,
    this.isSubItem = false,
  }) : super(key: key);

  final String route;
  final String title;
  final IconData icon;
  final bool isSubItem;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        AppNavigation.navigateFromDrawer(context, route);
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: isSubItem ? 12 : 16, 
          horizontal: isSubItem ? 32 : 16,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSubItem ? iconGrayColor.withOpacity(0.7) : iconGrayColor,
              size: isSubItem ? 20 : 24,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge!.color,
                fontSize: isSubItem ? 14 : 16,
                fontWeight: isSubItem ? FontWeight.w400 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
