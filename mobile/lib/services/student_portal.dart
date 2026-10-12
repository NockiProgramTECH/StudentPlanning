import 'package:flutter/services.dart';

class StudentPortal {
  static const _channel = MethodChannel('studia/student_portal');

  static Future<void> open(Uri uri) async {
    await _channel.invokeMethod<void>('open', uri.toString());
  }
}
