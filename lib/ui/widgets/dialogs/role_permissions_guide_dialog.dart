import 'package:flutter/material.dart';
import 'package:get/get.dart';

class RolePermissionsGuideDialog extends StatelessWidget {
  const RolePermissionsGuideDialog({Key? key}) : super(key: key);

  // Define role permissions and descriptions
  static const Map<String, Map<String, dynamic>> roleGuide = {
    'owner': {
      'title': 'Owner',
      'description': 'Full access to all features and settings',
      'permissions': ['All permissions', 'Full business control', 'Employee management', 'Financial oversight'],
      'color': Colors.purple,
      'icon': Icons.admin_panel_settings,
    },
    'manager': {
      'title': 'Manager',
      'description': 'Comprehensive management access with most permissions',
      'permissions': [
        'Manage products & inventory',
        'Make sales & view all sales',
        'Manage employees & clients',
        'Handle invoices & expenses',
        'View reports & statistics',
        'Transfer products between businesses',
        'Manage debt & transactions',
        'Buy products for business'
      ],
      'color': Colors.blue,
      'icon': Icons.supervisor_account,
    },
    'sales_person': {
      'title': 'Sales Person',
      'description':
          'Sales-focused role. Cannot access purchases or suppliers (even when Allow Purchases is on).',
      'permissions': [
        'View products',
        'Make sales',
        'View own sales only',
        'Manage clients',
        'Create & print invoices',
        'Share invoices',
        'Record client debt payments',
      ],
      'color': Colors.green,
      'icon': Icons.point_of_sale,
    },
    'cashier': {
      'title': 'Cashier',
      'description': 'Point-of-sale focused role for transactions',
      'permissions': [
        'View products',
        'Make sales',
        'View own sales only',
        'Manage clients',
        'Create & print invoices',
        'Share invoices'
      ],
      'color': Colors.orange,
      'icon': Icons.payment,
    },
    'agent': {
      'title': 'Agent',
      'description': 'Read-only access for monitoring and reporting',
      'permissions': [
        'View products',
        'View all sales (read-only)',
        'View reports',
        'View statistics'
      ],
      'color': Colors.grey,
      'icon': Icons.visibility,
    },
  };

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Role & Permissions Guide',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Choose the appropriate role based on what the employee should be able to do:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            
            // Role cards
            Expanded(
              child: ListView.builder(
                itemCount: roleGuide.length,
                itemBuilder: (context, index) {
                  final roleKey = roleGuide.keys.elementAt(index);
                  final roleData = roleGuide[roleKey]!;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ExpansionTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (roleData['color'] as Color).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          roleData['icon'] as IconData,
                          color: roleData['color'] as Color,
                          size: 24,
                        ),
                      ),
                      title: Text(
                        roleData['title'] as String,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: roleData['color'] as Color,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        roleData['description'] as String,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Permissions:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...(roleData['permissions'] as List<String>).map(
                                (permission) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: roleData['color'] as Color,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          permission,
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // Footer note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tip: You can also add custom permissions to any role for specific needs.',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
