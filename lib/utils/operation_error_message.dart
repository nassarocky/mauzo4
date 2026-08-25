import 'dart:async';

import 'package:firebase_core/firebase_core.dart';

const String internetRequiredMessage =
    'This operation requires an internet connection. Please connect to the internet and try again.';

String operationErrorMessage(Object error) {
  final code = error is FirebaseException ? error.code.toLowerCase() : '';
  final message = error.toString().toLowerCase();
  const networkCodes = {
    'unavailable',
    'deadline-exceeded',
    'network-request-failed',
    'retry-limit-exceeded',
  };

  if (error is TimeoutException ||
      networkCodes.contains(code) ||
      message.contains('/unavailable') ||
      message.contains('retry-limit-exceeded') ||
      message.contains('client is offline') ||
      message.contains('transaction requires') ||
      message.contains('requires an internet connection') ||
      message.contains('network is unreachable') ||
      message.contains('no internet connection') ||
      message.contains('failed to connect')) {
    return internetRequiredMessage;
  }

  return error.toString();
}
