import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image_picker/image_picker.dart';

class BarcodeScannerScreen extends StatefulWidget {
  @override
  _BarcodeScannerScreenState createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  String barcodeScanRes = '';
  final BarcodeScanner _barcodeScanner = BarcodeScanner();

  Future<void> _scanBarcode() async {
    try {
      final inputImage = await ImagePicker().pickImage(source: ImageSource.camera);
      if (inputImage == null) return;

      final input = InputImage.fromFilePath(inputImage.path);
      final List<Barcode> barcodes = await _barcodeScanner.processImage(input);
      
      if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
        final String code = barcodes.first.rawValue!;
        setState(() {
          barcodeScanRes = code;
        });
        Navigator.pop(context, barcodeScanRes);
      }
    } catch (e) {
      print('Error scanning barcode: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Scan Barcode')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center(
            child: ElevatedButton(
              onPressed: _scanBarcode,
              child: Text('Scan Barcode'),
            ),
          ),
          if (barcodeScanRes.isNotEmpty) 
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Scanned Code: $barcodeScanRes'),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _barcodeScanner.close();
    super.dispose();
  }
}
