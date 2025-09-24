import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../utils/constants.dart';
import '../tiles/drawer_tile.dart';

class ExpandableDrawerSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<DrawerMenuItem> items;
  final bool initiallyExpanded;

  const ExpandableDrawerSection({
    Key? key,
    required this.title,
    required this.icon,
    required this.items,
    this.initiallyExpanded = false,
  }) : super(key: key);

  @override
  State<ExpandableDrawerSection> createState() => _ExpandableDrawerSectionState();
}

class _ExpandableDrawerSectionState extends State<ExpandableDrawerSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    if (_isExpanded) {
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _toggleExpanded,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    widget.icon,
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.title.tr,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizeTransition(
          sizeFactor: _expandAnimation,
          child: Container(
            padding: const EdgeInsets.only(left: 16),
            child: Column(
              children: widget.items.map((item) {
                return DrawerTile(
                  title: item.title,
                  icon: item.icon,
                  route: item.route,
                  isSubItem: true,
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class DrawerMenuItem {
  final String title;
  final IconData icon;
  final String route;
  final bool Function()? condition;

  DrawerMenuItem({
    required this.title,
    required this.icon,
    required this.route,
    this.condition,
  });
}
