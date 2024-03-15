import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class IpTextFormat extends TextInputFormatter {

  final lastOctetPattern = r".[0-9]*$";

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {

    if (_manageCases(oldValue, newValue)) {
      return newValue;
    } else {
      return oldValue;
    }

  }

  bool _manageCases(TextEditingValue oldValue, TextEditingValue newValue) {

    // filter functions
    final List<bool Function(TextEditingValue)> filterFunctions = [
      _multiDotsNextTogether,
      _dotsLesserThan4,
      _valueContainsNumberDotEmpty,
      _lastOctetLengthLesserThan4,
      _lastOctetValueLesserThan255,
      _totalOctetsLesserThan5,
    ];

    for (var filter in filterFunctions) {
      if (filter(newValue) == false) return false;
    }

    return true;

  }

  bool _valueContainsNumberDotEmpty(TextEditingValue newValue) {

    RegExp reg = RegExp(r'^[0-9.]+$');

    return reg.hasMatch(newValue.text) || reg.stringMatch(newValue.text)!.isEmpty ? true : false;

  }

  bool _lastOctetLengthLesserThan4(TextEditingValue newValue) {

    RegExp reg = RegExp(lastOctetPattern);
    String lastOctet = reg.stringMatch(newValue.text)!;

    int startSubString = (lastOctet[0] == ".") ? 1 : 0;

    return lastOctet.substring(startSubString, lastOctet.length).length > 3
        ? false
        : true;

  }

  bool _lastOctetValueLesserThan255(TextEditingValue newValue) {

    String lastOctet = RegExp(lastOctetPattern).stringMatch(newValue.text)!;

    return int.parse(lastOctet.substring(1, lastOctet.length)) > 255
        ? false
        : true;

  }

  bool _totalOctetsLesserThan5(TextEditingValue newValue) => newValue.text.split(".").length > 4 ? false : true;

  bool _dotsLesserThan4(TextEditingValue newValue) => RegExp(r"\.").allMatches(newValue.text).length > 3 ? false : true;

  bool _multiDotsNextTogether(TextEditingValue newValue) {

    int lastIndex = newValue.text.length - 1;
    String lastChar = newValue.text[lastIndex];

    return lastChar == "." && lastChar == newValue.text[lastIndex - 1]
        ? false
        : true;

  }

}