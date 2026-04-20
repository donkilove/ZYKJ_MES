import 'package:flutter/foundation.dart';

class EffectiveClock extends ChangeNotifier {
  Duration _serverOffset = Duration.zero;
  bool _calibrated = false;

  DateTime now() => DateTime.now().add(_serverOffset);

  Duration get serverOffset => _serverOffset;
  bool get isCalibrated => _calibrated;

  void applyServerOffset(Duration offset) {
    _serverOffset = offset;
    _calibrated = true;
    notifyListeners();
  }

  void clearCalibration() {
    _serverOffset = Duration.zero;
    _calibrated = false;
    notifyListeners();
  }
}
