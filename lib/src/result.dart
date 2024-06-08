class BraintreeDropInResult {
  const BraintreeDropInResult({
    required this.paymentMethodNonce,
    required this.deviceData,
  });

  factory BraintreeDropInResult.fromJson(dynamic source) {
    return BraintreeDropInResult(
      paymentMethodNonce:
          BraintreePaymentMethodNonce.fromJson(source['paymentMethodNonce']),
      deviceData: source['deviceData'],
    );
  }

  /// The payment method nonce containing all relevant information for the payment.
  final BraintreePaymentMethodNonce paymentMethodNonce;

  /// String of device data. `null`, if `collectDeviceData` was set to false.
  final String? deviceData;
}

class BraintreePaymentMethodNonce {
  const BraintreePaymentMethodNonce({
    required this.nonce,
    required this.typeLabel,
    required this.description,
    required this.isDefault,
    this.paypalPayerId,
    this.billingAddress,
    this.firstName,
    this.lastName,
    this.email,
  });

  factory BraintreePaymentMethodNonce.fromJson(Map<dynamic, dynamic> source) {
    return BraintreePaymentMethodNonce(
      nonce: source['nonce'],
      typeLabel: source['typeLabel'],
      description: source['description'],
      isDefault: source['isDefault'],
      paypalPayerId: source['paypalPayerId'],
      firstName: source['firstName'] ?? "",
      lastName: source['lastName'] ?? "",
      email: source['email'] ?? "",
      billingAddress: source['billingAddress'] != null
          ? BraintreePostalAddress.fromJson(source['billingAddress'])
          : null,
    );
  }

  /// The nonce generated for this payment method by the Braintree gateway. The nonce will represent
  /// this PaymentMethod for the purposes of creating transactions and other monetary actions.
  final String nonce;

  /// The type of this PaymentMethod for displaying to a customer, e.g. 'Visa'. Can be used for displaying appropriate logos, etc.
  final String typeLabel;

  /// The description of this PaymentMethod for displaying to a customer, e.g. 'Visa ending in...'.
  final String description;

  /// user email.
  final String? email;

  /// user first name.
  final String? firstName;

  /// user last name.
  final String? lastName;

  /// True if this payment method is the default for the current customer, false otherwise.
  final bool isDefault;

  /// PayPal payer id if requesting for paypal nonce
  final String? paypalPayerId;

  /// Customer billing address returned when the nonce is generated
  final BraintreePostalAddress? billingAddress;
}

class BraintreePostalAddress {
  String? recipientName;
  String? streetAddress;
  String? extendedAddress;
  String? locality;
  String? countryCodeAlpha2;
  String? postalCode;
  String? region;

  BraintreePostalAddress(
      {this.recipientName,
      this.streetAddress,
      this.extendedAddress,
      this.locality,
      this.countryCodeAlpha2,
      this.postalCode,
      this.region});

  BraintreePostalAddress.fromJson(Map<dynamic, dynamic> json) {
    recipientName = json['recipientName'];
    streetAddress = json['streetAddress'];
    extendedAddress = json['extendedAddress'];
    locality = json['locality'];
    countryCodeAlpha2 = json['countryCodeAlpha2'];
    postalCode = json['postalCode'];
    region = json['region'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['recipientName'] = this.recipientName ?? "";
    data['streetAddress'] = this.streetAddress ?? "";
    data['extendedAddress'] = this.extendedAddress ?? "";
    data['locality'] = this.locality ?? "";
    data['countryCodeAlpha2'] = this.countryCodeAlpha2 ?? "";
    data['postalCode'] = this.postalCode ?? "";
    data['region'] = this.region ?? "";
    return data;
  }
}
