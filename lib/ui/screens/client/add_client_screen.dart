import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../controllers/business_controller.dart';
import '../../../controllers/profile_controller.dart';
import '../../../utils/constants.dart';
import '../../../utils/preferences.dart';
import '../../widgets/buttons/primary_button.dart';

class AddClientScreen extends StatefulWidget {
  const AddClientScreen({Key? key}) : super(key: key);

  @override
  State<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends State<AddClientScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final BusinessController _businessController = Get.find();
  final ProfileController _profileController = Get.find();
  final TextEditingController _noteController = TextEditingController();

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    
    // CRITICAL SECURITY CHECK: Verify user has permission to manage clients
    if (!_profileController.hasPermission('manage_clients')) {
      print('🚨 UNAUTHORIZED ACCESS BLOCKED: User tried to access AddClientScreen without manage_clients permission');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
        Get.snackbar(
          'Access Denied',
          'You do not have permission to add clients',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      });
      return;
    }
  }



  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => isLoading ? false : true,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor:
          Preferences.getTheme() ? darkGrayColor : primaryUltraLightColor,
          elevation: 0,
          leading: isLoading
              ? Container()
              : IconButton(
            icon: Icon(
              Icons.close,
              color: Theme.of(context).textTheme.bodyLarge!.color,
            ),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          title: Text(
            'new_client'.tr,
            style: TextStyle(
              color: Preferences.getTheme()
                  ? primaryUltraLightColor
                  : textDarkColor,
            ),
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  maxLength: 25,
                  decoration: InputDecoration(
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10),
                    labelText: '${'name'.tr}*',
                    counterText: '',
                    labelStyle: bodyText(textPlaceholderColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: borderColor),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 15,
                  decoration: InputDecoration(
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10),
                    labelText: 'phone'.tr,
                    counterText: '',
                    labelStyle: bodyText(textPlaceholderColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: borderColor),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _noteController,
                  maxLength: 50,
                  decoration: InputDecoration(
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10),
                    labelText: 'note'.tr,
                    counterText: '',
                    labelStyle: bodyText(textPlaceholderColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: borderColor),
                    ),
                  ),
                ),
                const SizedBox(height: 34),
                Row(
                  children: [
                    Expanded(
                      child: PrimaryButton(
                        onPressed: () async {
                          print('🔵 CLIENT CREATION: Starting client creation process');
                          
                          try {
                            if (_nameController.text.isEmpty) {
                              print('❌ CLIENT CREATION: Name field is empty');
                              errorSnackbar('fill_required_fields'.tr);
                              return;
                            }
                            
                            print('✅ CLIENT CREATION: Name validation passed');
                            setState(() {
                              isLoading = true;
                            });

                            final String? businessId = _businessController.business['id'];
                            print('🔵 CLIENT CREATION: Business ID = $businessId');

                            if (businessId == null) {
                              print('❌ CLIENT CREATION: Business ID is null');
                              setState(() {
                                isLoading = false;
                              });
                              errorSnackbar('Business ID is null');
                              return;
                            }

                            print('✅ CLIENT CREATION: Business ID validation passed');
                            
                            // Create document reference with auto-generated ID (like sales)
                            final newClientRef = firestore
                                .collection('clients')
                                .doc(businessId)
                                .collection('userClients')
                                .doc(); // Auto-generated ID
                            
                            print('🔵 CLIENT CREATION: Document reference created: ${newClientRef.path}');

                            // Client data to be added
                            final clientData = {
                              'name': _nameController.text.trim(),
                              'owner': businessId,
                              'debt': 0.0,
                              'phone': _phoneController.text.trim(),
                              'note': _noteController.text.trim(),
                              'date': Timestamp.now(),
                            };
                            
                            print('🔵 CLIENT CREATION: Client data prepared: $clientData');
                            print('🔵 CLIENT CREATION: Attempting Firestore set operation...');

                            // Use non-blocking .then() pattern like sales (works offline)
                            newClientRef.set(clientData).then((_) {
                              print('✅ CLIENT CREATION: Firestore operation completed successfully');
                              
                              // Successfully added to Firestore
                              setState(() {
                                isLoading = false;
                              });

                              if (mounted) {
                                Navigator.pop(context);
                              }
                              successSnackbar('client_added'.tr);
                            }).catchError((error) {
                              print('❌ CLIENT CREATION: Firestore operation failed: $error');
                              
                              errorSnackbar('Failed to add client: $error');
                              setState(() {
                                isLoading = false;
                              });
                            });
                            
                            print('🔵 CLIENT CREATION: Firestore operation initiated (non-blocking)');
                            
                          } catch (e) {
                            print('❌ CLIENT CREATION: Exception caught: $e');
                            print('❌ CLIENT CREATION: Exception type: ${e.runtimeType}');
                            print('❌ CLIENT CREATION: Stack trace: ${StackTrace.current}');
                            
                            errorSnackbar('Failed to add client: $e');
                            setState(() {
                              isLoading = false;
                            });
                            
                            // Don't auto-close on error so user can see the error
                          }
                        }
,
                        text: 'save'.tr,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
