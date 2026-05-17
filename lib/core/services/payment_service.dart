import 'package:cloud_functions/cloud_functions.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter/material.dart';

class PaymentService {
  late Razorpay _razorpay;
  Function(String)? _onSuccess;
  Function(String)? _onFailure;
  
  int _pendingAmount = 0;

  void initialize() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void dispose() {
    _razorpay.clear();
  }

  // STEP 1: Create Order & Open Standard Checkout
  Future<void> openCheckout({
    required int amount,
    required String matchName,
    required String userPhone,
    required String userEmail,
    required Function(String) onSuccess,
    required Function(String) onFailure,
  }) async {
    _onSuccess = onSuccess;
    _onFailure = onFailure;
    _pendingAmount = amount;

    try {
      final functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
      final result = await functions.httpsCallable('createRazorpayOrder').call({
        'amount': amount,
      });

      final orderId = result.data['orderId'];
      final keyId = result.data['keyId']; 

      var options = {
        'key': keyId, 
        'amount': amount * 100, // Amount in paise
        'name': 'LOQX ARENA',
        'description': matchName, // Shows match name in payment
        'order_id': orderId, 
        'prefill': {
          'contact': userPhone, 
          'email': userEmail
        },
        'theme': {'color': '#FFD700'}, // Gold Theme
        'retry': {'enabled': true, 'max_count': 1},
        'send_sms_hash': true,
      };

      _razorpay.open(options);
    } on FirebaseFunctionsException catch (e) {
      _onFailure?.call("Server Error: ${e.message}");
    } catch (e) {
      _onFailure?.call("Initialization Error: ${e.toString()}");
    }
  }

  // STEP 2: Verify Payment
  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
      
      final verifyResult = await functions.httpsCallable('verifyPayment').call({
        'orderId': response.orderId,
        'paymentId': response.paymentId,
        'signature': response.signature,
        'amount': _pendingAmount, 
      });
      
      if (verifyResult.data['success'] == true) {
        _onSuccess?.call(response.paymentId ?? "Success");
      } else {
        _onFailure?.call("Payment Verification Failed. Contact Support.");
      }
    } on FirebaseFunctionsException catch (e) {
      // Graceful error handling instead of red screen
      _onFailure?.call("Verification Failed: ${e.message}");
    } catch (e) {
      _onFailure?.call("Verification Error: $e");
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _onFailure?.call("Payment Cancelled or Failed: ${response.message}");
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _onFailure?.call("External Wallet Selected: ${response.walletName}");
  }
}