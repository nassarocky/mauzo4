import 'dart:convert';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../controllers/business_controller.dart';
import 'package:http/http.dart' as http;
import '../../../controllers/profile_controller.dart';
import '../../../utils/constants.dart';
import '../../../utils/image.dart';
import '../../../utils/preferences.dart';
import '../../widgets/buttons/primary_button.dart';

Future<void> registerUser({
  required String name,
  required String phoneOrEmail,
  required String password,
  required String business,
  String role = 'employee', // Default to 'employee' for backward compatibility
}) async {
  final Uri url = Uri.parse('https://registeruser-z3bhqccxda-uc.a.run.app');

  try {
    // Sending POST request to Cloud Function (backend detects email vs phone)
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'phoneOrEmail': phoneOrEmail.trim(),
        'password': password,
        'business': business,
        'role': role,
      }),
    );

    // Handle successful response
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      final String userId = data['userId'];
      successSnackbar('User successfully registered! User ID: $userId');
    }
    // Handle different error cases
    else if (response.statusCode == 400) {
      final error = response.body; // Read the specific error message
      errorSnackbar('Error400: $error');
    } else {
      errorSnackbar('Failed to register user. Please try again later.');
    }
  } catch (e) {
    // Handle network or server errors
    errorSnackbar('Error: ${e.toString()}');
  }
}

void successSnackbar(String message) {
  Get.snackbar(
    'Success',
    message,
    snackPosition: SnackPosition.BOTTOM,
    backgroundColor: Colors.green,
    colorText: Colors.white,
    duration: Duration(seconds: 3),
  );
}

void errorSnackbar(String message) {
  Get.snackbar(
    'Error',
    message,
    snackPosition: SnackPosition.BOTTOM,
    backgroundColor: Colors.red,
    colorText: Colors.white,
    duration: Duration(seconds: 3),
  );
}

class AddEmployeeScreen extends StatefulWidget {
  const AddEmployeeScreen({Key? key}) : super(key: key);

  @override
  State<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen> {
  String _selectedRole = 'sales_person';

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneOrEmailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final BusinessController _businessController = Get.find();
  final ProfileController _profileController = Get.find();

  File? imageFile;
  UploadTask? uploadTask;
  bool isUploading = false;

  @override
  void initState() {
    super.initState();
    
    // CRITICAL SECURITY CHECK: Verify user has permission to manage employees
    if (!_profileController.hasPermission('manage_employees')) {
      print('🚨 UNAUTHORIZED ACCESS BLOCKED: User tried to access AddEmployeeScreen without manage_employees permission');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
        Get.snackbar(
          'Access Denied',
          'You do not have permission to add employees',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      });
      return;
    }
  }

  Future<String?> uploadFile(String folder, File file) async {
    try {
      final path = '$folder/${DateTime.now().millisecondsSinceEpoch}.png';
      final ref = FirebaseStorage.instance.ref().child(path);
      uploadTask = ref.putFile(file);
      final snapshot = await uploadTask!.whenComplete(() => {});
      final url = await snapshot.ref.getDownloadURL();
      return url;
    } catch (e) {
      _showSnackbar('Upload failed: $e');
      throw Exception('File upload failed: $e');
    }
  }

  Future<void> pickImageFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        imageFile = File(pickedFile.path);
        // _showSnackbar('Image picked from gallery: ${pickedFile.path}');
      });
    }
  }

  Future<void> pickImageFromCamera() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        imageFile = File(pickedFile.path);
        //  _showSnackbar('Image picked from camera: ${pickedFile.path}');
      });
    }
  }
  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  bool isValidEmail(String email) {
    return RegExp(r"^[a-zA-Z0-9._%-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$")
        .hasMatch(email);
  }

  /// `@` → valid email; otherwise treat as phone (TZ-friendly, matches owner registration).
  bool isValidPhoneOrEmail(String value) {
    final t = value.trim();
    if (t.isEmpty) return false;
    if (t.contains('@')) return isValidEmail(t);
    final d = t.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.startsWith('0') && d.length == 10) return true;
    if (d.length == 9 && !d.startsWith('255')) return true;
    if (d.startsWith('255') && d.length >= 12) return true;
    return d.length >= 10;
  }

  bool isValidPassword(String password) {
    return password.length >= 8;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => isUploading ? false : true,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor:
          Preferences.getTheme() ? darkGrayColor : primaryUltraLightColor,
          elevation: 0,
          leading: isUploading
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
            'new_employee'.tr,
            style: TextStyle(
              color: Preferences.getTheme()
                  ? primaryUltraLightColor
                  : textDarkColor,
            ),
          ),
        ),
        body: isUploading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Center(
                  child: GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text('select_image_source'.tr),
                          content: SizedBox(
                            height: 180,
                            child: Column(
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.collections),
                                  title: Text('gallery'.tr),
                                  onTap: () async {
                                    await pickImageFromGallery();
                                    Navigator.pop(context);
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.camera),
                                  title: Text('camera'.tr),
                                  onTap: () async {
                                    await pickImageFromCamera();
                                    Navigator.pop(context);
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.close),
                                  title: Text('delete'.tr),
                                  onTap: () {
                                    setState(() {
                                      imageFile = null;
                                      Navigator.pop(context);
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    child: imageFile != null
                        ? Container(
                      decoration: BoxDecoration(
                        color: gray200Color,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      width: 72,
                      height: 72,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: Image.file(
                          imageFile!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                        : const CircleAvatar(
                      radius: 36,
                      backgroundColor: gray200Color,
                      child: Icon(
                        Icons.person,
                        size: 44,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
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
                  controller: _phoneOrEmailController,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10),
                    labelText: '${'phone_or_email'.tr}*',
                    hintText: 'user@email.com, +255…, 0712…',
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
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10),
                    labelText: 'password'.tr,
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
                // Role selection
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(value: 'owner', child: Text('owner'.tr)),
                    DropdownMenuItem(value: 'manager', child: Text('manager'.tr)),
                    DropdownMenuItem(value: 'cashier', child: Text('cashier'.tr)),
                    DropdownMenuItem(value: 'sales_person', child: Text('sales_person'.tr)),
                    DropdownMenuItem(value: 'agent', child: Text('agent'.tr)),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedRole = value!;
                    });
                  },
                ),

                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: PrimaryButton(
                        onPressed: () async {
                          try {
                            if (_nameController.text.isEmpty ||
                                _phoneOrEmailController.text.isEmpty ||
                                _passwordController.text.isEmpty) {
                              errorSnackbar('fill_required_fields'.tr);
                            } else if (!isValidPhoneOrEmail(_phoneOrEmailController.text)) {
                              errorSnackbar('invalid_phone_or_email'.tr);
                            } else if (!isValidPassword(_passwordController.text)) {
                              errorSnackbar('Password must be at least 8 characters.');
                            } else {
                              setState(() {
                                isUploading = true;
                              });

                              String? url = '';
                              if (imageFile != null) {
                                url = await uploadFile(
                                    'employees', imageFile!);
                              }

                              final String? businessId = _businessController.business['id'];

                              if (businessId == null) {
                                print('business ID is null, cannot add employee.');
                                setState(() {
                                  isUploading = false;
                                });
                                return;
                              }

                              await registerUser(
                                name: _nameController.text,
                                phoneOrEmail: _phoneOrEmailController.text,
                                password: _passwordController.text,
                                business: businessId,
                                role: _selectedRole,
                              );

                              setState(() {
                                isUploading = false;
                              });

                              if (mounted) {
                                Navigator.pop(context);
                              }
                              successSnackbar('Employee added successfully.');
                            }
                          } catch (e) {
                            errorSnackbar('something_went_wrong'.tr);
                            Navigator.pop(context);
                          }
                        },
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
