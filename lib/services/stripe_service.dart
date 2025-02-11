import 'dart:js' as js; // For web compatibility
import 'package:dio/dio.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter/foundation.dart'; // For platform checks
import 'package:care_nest/stripeSecretKey.dart'; // Your Stripe secret key

class StripeService {
  StripeService._();
  static final StripeService instance = StripeService._();

  Future<void> makePayment(int amount, String currency) async {
    try {
      if (kIsWeb) {
        // Use Stripe Checkout for web
        String? checkoutUrl = await _createCheckoutSession(amount, currency);
        if (checkoutUrl != null) {
          js.context.callMethod('open', [checkoutUrl]); // Open Checkout in browser
        }
      } else {
        // Use Payment Sheet for mobile
        String? paymentIntentClientSecret = await _createPaymentIntent(amount, currency);
        if (paymentIntentClientSecret == null) return;

        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: paymentIntentClientSecret,
            merchantDisplayName: "CareNest",
          ),
        );

        await Stripe.instance.presentPaymentSheet(); // Show the Payment Sheet
      }
    } catch (e) {
      print("Payment Error: $e");
    }
  }

  Future<String?> _createPaymentIntent(int amount, String currency) async {
    try {
      final Dio dio = Dio();
      Map<String, dynamic> data = {
        "amount": _calculateAmount(amount),
        "currency": currency,
        "payment_method": 'pm_card_visa',
        "payment_method_types[]": "card",
      };

      var response = await dio.post(
        "https://api.stripe.com/v1/payment_intents",
        data: data,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            "Authorization": "Bearer $secretKey", // Use your Stripe Secret Key
            "Content-Type": 'application/x-www-form-urlencoded',
          },
        ),
      );

      if (response.data != null) {
        return response.data["client_secret"];
      }
    } catch (e) {
      print("Error creating Payment Intent: $e");
    }
    return null;
  }

  Future<String?> _createCheckoutSession(int amount, String currency) async {
    try {
      final Dio dio = Dio();
      Map<String, dynamic> data = {
        "success_url": "http://localhost:8080/success.html", // Replace with your success page URL
        "cancel_url": "http://localhost:8080/cancel.html",   // Replace with your cancel URL
        "payment_method_types[]": "card",
        "line_items[0][price_data][currency]": currency,
        "line_items[0][price_data][product_data][name]": "Donation",
        "line_items[0][price_data][unit_amount]": _calculateAmount(amount),
        "line_items[0][quantity]": 1,
        "mode": "payment",
      };

      var response = await dio.post(
        "https://api.stripe.com/v1/checkout/sessions",
        data: data,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            "Authorization": "Bearer $secretKey", // Use your Stripe Secret Key
            "Content-Type": 'application/x-www-form-urlencoded',
          },
        ),
      );

      if (response.data != null) {
        return response.data["url"];
      }
    } catch (e) {
      print("Error creating Checkout Session: $e");
    }
    return null;
  }

  String _calculateAmount(int amount) {
    final calculatedAmount = amount * 100; // Convert to cents
    return calculatedAmount.toString();
  }
}
