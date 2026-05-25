import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../utils/constants.dart';
import '../../utils/purchases_access.dart';

/// Shown when a purchase/supplier route is opened while Allow Purchases is off.
class PurchasesBlockedScreen extends StatelessWidget {
  const PurchasesBlockedScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text('Purchases'.tr),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.block,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'purchases_disabled_by_admin'.tr,
                textAlign: TextAlign.center,
                style: h5(Theme.of(context).textTheme.bodyLarge?.color),
              ),
              const SizedBox(height: 24),
              CupertinoButton.filled(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text('back'.tr),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
