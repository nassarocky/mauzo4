import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Privacy Policy"),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Privacy Policy for Hesabu Mauzo",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Effective Date: 9 September 2024",
              style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
            ),
            SizedBox(height: 16),
            Text(
              "At Hesabu Mauzo, we are committed to protecting your privacy and ensuring that your personal information is handled in a safe and responsible manner. This Privacy Policy outlines how we collect, use, and safeguard the information you provide when using our services.",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              "1. Information We Collect",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "When you use Hesabu Mauzo, we may collect the following personal information:",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 8),
            Text("• Name: To identify the user of our system."),
            Text("• Email Address: To communicate important information about your account, updates, and notifications."),
            Text("• Phone Number: To contact you for support and other business-related communications."),
            SizedBox(height: 16),
            Text(
              "2. How We Use Your Information",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "We use the information we collect to:",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 8),
            Text("• Provide access to the Hesabu Mauzo system and maintain your account."),
            Text("• Improve our services and ensure the platform functions smoothly."),
            Text("• Communicate with you for updates, support, and other service-related purposes."),
            Text("• Ensure the security of our system and protect against unauthorized access."),
            SizedBox(height: 16),
            Text(
              "3. Data Security",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "We take reasonable precautions to protect your personal information from unauthorized access, disclosure, or misuse. However, no method of transmission over the Internet is 100% secure, and we cannot guarantee absolute security.",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              "4. Sharing of Information",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "We do not share your personal information with third parties.",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              "5. Your Rights",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "You have the right to:",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 8),
            Text("• Access the personal information we hold about you."),
            Text("• Withdraw consent to the use of your personal information."),
            SizedBox(height: 16),
            Text(
              "If you wish to exercise any of these rights, please contact us using the information provided below.",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              "6. Changes to This Privacy Policy",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "We reserve the right to update this Privacy Policy from time to time. Any changes will be posted on this page, and we encourage you to review it periodically to stay informed.",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              "7. Contact Us",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "If you have any questions or concerns about this Privacy Policy, or if you wish to exercise your rights regarding your personal data, please contact us:",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 8),
            Text("• Email: goodnassah1@gmail.com"),
            Text("• Phone: +255 653 422 101"),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
