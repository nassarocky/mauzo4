import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore package
import 'package:get/get.dart';
import 'package:mauzo/utils/constants.dart';
import 'package:url_launcher/link.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({Key? key}) : super(key: key);

  @override
  _SupportScreenState createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  String phoneNumber = '+255698720225/+255781282076';

  @override
  void initState() {
    super.initState();
  }

  double getFontSize(BuildContext context, double baseFontSize) {
    // Adjust font size based on screen width
    double screenWidth = MediaQuery.of(context).size.width;
    return screenWidth > 600 ? baseFontSize * 1.5 : baseFontSize; // Larger for tablets
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'support'.tr,
          style: TextStyle(fontSize: getFontSize(context, 18)), // Responsive font size
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 18.0),
          child: Column(
            children: [
              Center(
                child: Image.asset(
                  'assets/images/hesabu_mauzo_logo.png',
                  height: 88,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 200,
                child: Text(
                  'support_description'.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: getFontSize(context, 14),
                    color: Theme.of(context).textTheme.bodyMedium!.color,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: primaryUltraLightColor,
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: SizedBox(
                        width: 38,
                        height: 38,
                        child: Image.asset(
                          'assets/images/telegram.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Phone',
                          style: TextStyle(fontSize: getFontSize(context, 14), color: textDarkColor),
                        ),
                        Text(
                          phoneNumber.isEmpty ? 'Loading...' : phoneNumber,
                          style: TextStyle(fontSize: getFontSize(context, 14), color: textDarkColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: primaryUltraLightColor,
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: Container(
                        color: primaryColor,
                        width: 38,
                        height: 38,
                        child: const Icon(Icons.email, color: whiteColor),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Email',
                          style: TextStyle(fontSize: getFontSize(context, 14), color: textDarkColor),
                        ),
                        Link(
                          uri: Uri.parse('mailto:info@hesabumauzo.co.tz'),
                          builder: (context, followLink) => GestureDetector(
                            onTap: followLink,
                            child: Text(
                              'info@hesabumauzo.co.tz',
                              style: TextStyle(fontSize: getFontSize(context, 14), color: primaryColor),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
