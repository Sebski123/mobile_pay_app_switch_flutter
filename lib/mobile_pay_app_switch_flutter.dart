import 'dart:async';

import 'package:flutter/services.dart';

class MobilePay {
  static MobilePay _instance;

  factory MobilePay() {
    _instance ??= MobilePay._create();
    return _instance;
  }

  Map<String, Completer<MobilePayResult>> _orders = {};

  MobilePay._create() {
    _channel.setMethodCallHandler(methodCallHandler);
  }

  final MethodChannel _channel = const MethodChannel('mobile_pay_flutter');

  Future<void> init(
      String merchantId, MobilePayCountry country, String merchantUrlScheme) {
    return _channel.invokeMethod('initMobilePay', {
      'merchantId': merchantId,
      'country': _getCountryCode(country),
      'merchantUrlScheme': merchantUrlScheme
    });
  }

  Future<void> setRequestCode(int requestCode) {
    return _channel
        .invokeMethod('setRequestCode', {'requestCode': requestCode});
  }

  Future<MobilePayResult> createPayment({double productPrice, String orderId}) {
    assert(productPrice != null);
    assert(orderId != null);
    final completer = new Completer<MobilePayResult>();
    _orders[orderId] = completer;
    _channel.invokeMethod('createPayment', {
      'productPrice': productPrice,
      'orderId': orderId
    }).catchError((e) => throw e);
    return completer.future;
  }

  Future<void> downloadMobilePay() {
    return _channel.invokeMethod('downloadMobilePay');
  }

  Future<bool> get isMobilePayInstalled {
    return _channel.invokeMethod('isMobilePayInstalled');
  }

  Future<dynamic> methodCallHandler(MethodCall call) async {
    switch (call.method) {
      case "mobilePaySuccess":
        final String orderId = call.arguments["orderId"];
        final completer = _orders[orderId];
        if (completer != null) {
          Map<String, dynamic> arguments =
              Map<String, dynamic>.from(call.arguments);
          completer.complete(MobilePayResult.success(arguments));
        }
        break;
      case "mobilePayFailure":
        final String orderId = call.arguments["orderId"];
        final completer = _orders[orderId];
        if (completer != null) {
          Map<String, dynamic> arguments =
              Map<String, dynamic>.from(call.arguments);
          completer.complete(MobilePayResult.failure(arguments));
        }
        break;
      case "mobilePayCancel":
        final String orderId = call.arguments["orderId"];
        final completer = _orders[orderId];
        if (completer != null) {
          Map<String, dynamic> arguments =
              Map<String, dynamic>.from(call.arguments);
          completer.complete(MobilePayResult.canceled(arguments));
        }
        break;
    }
  }
}

class MobilePayResult {
  final String orderId;

  final double amountWithdrawnFromCard;
  final String signature;
  final String transactionId;

  final int errorCode;
  final String errorMessage;

  final bool isSuccess;
  final bool isFailure;
  final bool isCanceled;

  MobilePayResult.success(Map<String, dynamic> arguments)
      : orderId = arguments['orderId'],
        amountWithdrawnFromCard = arguments['amountWithdrawnFromCard'],
        signature = arguments['signature'],
        transactionId = arguments['transactionId'],
        errorCode = null,
        errorMessage = null,
        isSuccess = true,
        isFailure = false,
        isCanceled = false;

  MobilePayResult.failure(Map<String, dynamic> arguments)
      : orderId = arguments['orderId'],
        amountWithdrawnFromCard = null,
        signature = null,
        transactionId = null,
        errorCode = arguments['errorCode'],
        errorMessage = arguments['errorMessage'],
        isSuccess = false,
        isFailure = true,
        isCanceled = false;

  MobilePayResult.canceled(Map<String, dynamic> arguments)
      : orderId = arguments['orderId'],
        amountWithdrawnFromCard = null,
        signature = null,
        transactionId = null,
        errorCode = null,
        errorMessage = null,
        isSuccess = false,
        isFailure = false,
        isCanceled = true;
}

String _getCountryCode(MobilePayCountry country) {
  switch (country) {
    case MobilePayCountry.FINLAND:
      return "fi";
    case MobilePayCountry.DENMARK:
      return "dk";
    default:
      return 'dk';
  }
}

enum MobilePayCountry { FINLAND, DENMARK }
