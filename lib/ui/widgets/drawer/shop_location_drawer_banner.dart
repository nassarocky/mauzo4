import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Drawer reminder for owners when shop city/street are missing.
class ShopLocationDrawerBanner extends StatelessWidget {
  const ShopLocationDrawerBanner({
    Key? key,
    required this.onTap,
  }) : super(key: key);

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.95);
    final fg = Theme.of(context).colorScheme.onSecondaryContainer;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          color: bg,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.place_outlined, color: fg, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'shop_location_banner_title'.tr,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: fg,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'shop_location_banner_subtitle'.tr,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.25,
                        color: fg.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: fg.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}
