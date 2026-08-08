enum CardType { visa, mastercard, amex, discover, jcb, dinersClub, unionpay, maestro, unknown }

class CardDetector {
  /// Cleans input by removing non-digit characters.
  static String _cleanNumber(String input) => input.replaceAll(RegExp(r'[^0-9]'), '');

  /// Detect card type by prefix (IIN/BIN) and sometimes length hints.
  /// Returns CardType.unknown if no match.
  static CardType detectCardType(String input) {
    final number = _cleanNumber(input);
    if (number.isEmpty) return CardType.unknown;

    // Quick prefix checks (most common ranges). We use startsWith and numeric ranges
    // for ranges that can't be expressed simply by startsWith.

    // VISA: starts with 4
    if (number.startsWith('4')) return CardType.visa;

    // American Express: 34 or 37
    if (number.startsWith('34') || number.startsWith('37')) return CardType.amex;

    // MasterCard:
    // - 51-55 (legacy)
    // - 2221-2720 (new range since 2017)
    if (_inRangePrefix(number, 51, 55, 2) || _inRangePrefix(number, 2221, 2720, 4)) {
      return CardType.mastercard;
    }

    // Discover: Check specific ranges first to avoid conflicts
    // 6011, 65, 644-649, 622126-622925
    if (number.startsWith('6011') ||
        number.startsWith('65') ||
        _inRangePrefix(number, 644, 649, 3) ||
        _inRangePrefix(number, 622126, 622925, 6)) {
      return CardType.discover;
    }

    // JCB: 3528-3589 (first 4 digits)
    if (_inRangePrefix(number, 3528, 3589, 4)) return CardType.jcb;

    // Diners Club (common prefixes):
    // 300-305, 36, 38, 39
    if (_inRangePrefix(number, 300, 305, 3) ||
        number.startsWith('36') ||
        number.startsWith('38') ||
        number.startsWith('39')) {
      return CardType.dinersClub;
    }

    // UnionPay (China) - check after Discover to avoid conflicts
    // Common prefixes: 62, 81
    if (number.startsWith('62') || number.startsWith('81')) {
      return CardType.unionpay;
    }

    // Maestro (Debit card, various prefixes)
    final maestroPrefixes = [
      '5018',
      '5020',
      '5038',
      '5893',
      '6304',
      '6759',
      '6761',
      '6762',
      '6763',
    ];
    for (final prefix in maestroPrefixes) {
      if (number.startsWith(prefix)) return CardType.maestro;
    }

    return CardType.unknown;
  }

  /// Luhn algorithm to check numeric validity (catches typos).
  /// Returns false for empty or non-digit inputs.
  static bool isValidLuhn(String input) {
    final number = _cleanNumber(input);
    if (number.isEmpty) return false;

    int sum = 0;
    final len = number.length;
    final parity = len % 2;

    for (int i = 0; i < len; i++) {
      int digit = int.parse(number[i]);
      if (i % 2 == parity) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
    }
    return sum % 10 == 0;
  }

  /// Helper: check whether the first [prefixLength] digits (if available)
  /// form a number within [low..high] inclusive.
  static bool _inRangePrefix(String number, int low, int high, int prefixLength) {
    if (number.length < prefixLength) return false;
    final prefix = int.tryParse(number.substring(0, prefixLength));
    if (prefix == null) return false;
    return prefix >= low && prefix <= high;
  }

  /// Get possible card number lengths for a given card type
  static List<int> getPossibleLengths(CardType type) {
    switch (type) {
      case CardType.visa:
        return [13, 16, 19]; // 13-digit are rare legacy cards
      case CardType.mastercard:
        return [16];
      case CardType.amex:
        return [15];
      case CardType.discover:
        return [16, 19]; // Added 19-digit support
      case CardType.jcb:
        return [16, 17, 18, 19];
      case CardType.dinersClub:
        return [14, 16]; // Some Diners Club cards are 16 digits
      case CardType.unionpay:
        return [16, 17, 18, 19];
      case CardType.maestro:
        return [12, 13, 14, 15, 16, 17, 18, 19];
      case CardType.unknown:
        return [];
    }
  }

  /// Validates both card type detection and Luhn algorithm
  static bool isValidCard(String input) {
    final number = _cleanNumber(input);
    if (number.isEmpty) return false;

    final cardType = detectCardType(number);
    if (cardType == CardType.unknown) return false;

    final possibleLengths = getPossibleLengths(cardType);
    if (!possibleLengths.contains(number.length)) return false;

    return isValidLuhn(number);
  }

  /// Get a human-readable card type name
  static String getCardTypeName(CardType type) {
    switch (type) {
      case CardType.visa:
        return 'Visa';
      case CardType.mastercard:
        return 'Mastercard';
      case CardType.amex:
        return 'American Express';
      case CardType.discover:
        return 'Discover';
      case CardType.jcb:
        return 'JCB';
      case CardType.dinersClub:
        return 'Diners Club';
      case CardType.unionpay:
        return 'UnionPay';
      case CardType.maestro:
        return 'Maestro';
      case CardType.unknown:
        return 'Unknown';
    }
  }
}
