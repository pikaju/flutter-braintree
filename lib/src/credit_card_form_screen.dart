import 'dart:developer';

import 'package:braintree_flutter_plus/src/formatter/input_four_digit_format.dart';
import 'package:braintree_flutter_plus/src/widgets/image_view_component.dart';
import 'package:braintree_flutter_plus/src/widgets/text_field_widget.dart';
import 'package:braintree_flutter_plus/src/formatter/card_detector.dart';
import 'package:flutter/material.dart';
import '../braintree_flutter_plus.dart';

class CreditCardFormScreen extends StatefulWidget {
  const CreditCardFormScreen({
    super.key,
    required this.authorization,
    required this.amount,
    this.collectDeviceData = false,
    this.requestThreeDSecureVerification = false,
    this.billingAddress,
    this.email,
  });

  final String authorization;
  final String amount;
  final bool collectDeviceData;
  final bool requestThreeDSecureVerification;
  final BraintreeBillingAddress? billingAddress;
  final String? email;

  @override
  State<CreditCardFormScreen> createState() => _CreditCardFormScreenState();
}

class _CreditCardFormScreenState extends State<CreditCardFormScreen> {
  final _cardNumberController = TextEditingController();
  final _expirationMonthController = TextEditingController();
  final _expirationYearController = TextEditingController();
  final _cvvController = TextEditingController();
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
  CardType _detectedCardType = CardType.unknown;

  @override
  void initState() {
    super.initState();
    _cardNumberController.addListener(_onCardNumberChanged);
  }

  @override
  void dispose() {
    _cardNumberController.removeListener(_onCardNumberChanged);
    super.dispose();
  }

  void _onCardNumberChanged() {
    final cardType = CardDetector.detectCardType(_cardNumberController.text);
    if (cardType != _detectedCardType) {
      log('Card type changed to $cardType');
      setState(() {
        _detectedCardType = cardType;
      });
    }
  }

  Widget _getCardIcon(CardType cardType) {
    const double iconSize = 24.0;

    switch (cardType) {
      case CardType.visa:
        return _buildCardIcon('assets/images/visa_icon.png', iconSize);
      case CardType.mastercard:
        return _buildCardIcon('assets/images/mastercard_icon.jpg', iconSize);
      case CardType.amex:
        return _buildCardIcon('assets/images/amex_icon.png', iconSize);
      case CardType.discover:
        return _buildCardIcon('assets/images/discover_icon.jpg', iconSize);
      case CardType.jcb:
        return _buildCardIcon('assets/images/jcb_icon.jpg', iconSize);
      case CardType.dinersClub:
        return _buildCardIcon('assets/images/dinersclub_icon.png', iconSize);
      case CardType.unionpay:
        return _buildCardIcon('assets/images/unionpay_icon.png', iconSize);
      case CardType.maestro:
        return _buildCardIcon('assets/images/maestro_icon.png', iconSize);
      case CardType.unknown:
        return Icon(Icons.credit_card, size: iconSize, color: Colors.blue);
    }
  }

  Widget _buildCardIcon(String assetPath, double size) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ImageViewComponent.asset(
        path: assetPath,
        width: size,
        packageName: 'braintree_flutter_plus',
        height: size,
        fit: BoxFit.contain,
        errorPlaceholder: Icon(Icons.credit_card, size: size, color: Colors.grey),
      ),
    );
  }

  Future<void> _tokenizeCard() async {
    setState(() {
      _isLoading = true;
    });

    final request = BraintreeCreditCardRequest(
      cardNumber: _cardNumberController.text.replaceAll(' ', ''),
      expirationMonth: _expirationMonthController.text,
      expirationYear: _expirationYearController.text,
      cvv: _cvvController.text,
      amount: widget.amount,
    );

    try {
      final nonce = await Braintree.tokenizeCreditCard(
        widget.authorization,
        request,
        collectDeviceData: widget.collectDeviceData,
        requestThreeDSecureVerification: widget.requestThreeDSecureVerification,
        billingAddress: widget.billingAddress,
        email: widget.email,
      );
      Navigator.of(context).pop(nonce);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Enter Card Details')),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CustomTextFormField(
                    suffixIcon: _getCardIcon(_detectedCardType),
                    errorText: 'Card number is required',
                    controller: _cardNumberController,
                    labelText: 'Card Number',
                    keyboardType: TextInputType.number,
                    maxLength: 19,
                    inputFormatters: [FourDigitSeparatorFormatter()],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Card number is required';
                      }

                      final cleanNumber = value.replaceAll(' ', '');

                      if (!CardDetector.isValidLuhn(cleanNumber)) {
                        return 'Invalid card number';
                      }

                      final cardType = CardDetector.detectCardType(cleanNumber);
                      final possibleLengths = CardDetector.getPossibleLengths(cardType);

                      if (cardType != CardType.unknown && possibleLengths.isNotEmpty) {
                        if (!possibleLengths.contains(cleanNumber.length)) {
                          return 'Invalid card number length';
                        }
                      }

                      return null;
                    },
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: CustomTextFormField(
                          controller: _expirationMonthController,
                          labelText: 'Exp. Month (MM)',
                          hintText: 'MM',
                          maxLength: 2,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Month is required';
                            }
                            if (value.length < 2) {
                              return 'Invalid month';
                            }
                            if ((int.tryParse(value) ?? 0) > 12) {
                              return 'Invalid month';
                            }

                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: CustomTextFormField(
                          controller: _expirationYearController,
                          labelText: 'Exp. Year (YYYY)',
                          hintText: 'YYYY',
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Expiration year is required';
                            }
                            if ((int.tryParse(value) ?? 0) < DateTime.now().year) {
                              return 'Card expired';
                            }
                            if (value.length < 4) {
                              return 'Invalid year';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  CustomTextFormField(
                    isPassword: true,
                    errorText: 'CVV is required',
                    controller: _cvvController,
                    hintText: 'CVV',
                    maxLength: 4,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'CVV is required';
                      }
                      if (value.length < 3) {
                        return 'Invalid CVV';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 24),
                  _isLoading
                      ? Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            if (!_formKey.currentState!.validate()) {
                              return;
                            }
                            await _tokenizeCard();
                          },
                          child: Text(
                            'Pay',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
