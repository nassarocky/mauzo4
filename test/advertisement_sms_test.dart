import 'package:flutter_test/flutter_test.dart';
import 'package:mauzo/utils/advertisement_sms.dart';

void main() {
  test('advertisement template personalizes client and business', () {
    final message = applyAdvertisementTemplate(
      'Habari {name}, ofa mpya kutoka {business}.',
      clientName: 'Asha',
      businessName: 'Duka Bora',
    );

    expect(message, 'Habari Asha, ofa mpya kutoka Duka Bora.');
  });

  test('advertisement segment count includes personalized values', () {
    final segments = advertisementSmsSegments(
      'Hello {name}, visit {business}.',
      clientName: 'Asha',
      businessName: 'Hesabu Mauzo',
    );

    expect(segments, 1);
  });
}
