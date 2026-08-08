import 'package:flutter/services.dart';

class FourDigitSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String newText = newValue.text.replaceAll(RegExp(r'\s+'), ''); // Remove existing spaces
    if (newText.isNotEmpty) {
      String formattedText = '';
      for (int i = 0; i < newText.length; i++) {
        formattedText += newText[i];
        if ((i + 1) % 4 == 0 && i != newText.length - 1) {
          formattedText += ' '; // Add a space after every 4 digits
        }
      }
      return TextEditingValue(
        text: formattedText,
        selection: TextSelection.collapsed(offset: formattedText.length),
      );
    }
    return newValue;
  }
}
