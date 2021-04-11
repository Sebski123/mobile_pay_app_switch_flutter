import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:mobile_pay_app_switch_flutter/mobile_pay_app_switch_flutter.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _mobilePlayInstalled = false;
  bool _loading = false;
  MobilePayResult _paymentResult;

  @override
  void initState() {
    super.initState();
    initMobilePay();
  }

  Future<void> initMobilePay() async {
    bool mobilePlayInstalled;

    MobilePay().init("APPFI0000000000", MobilePayCountry.FINLAND, "mbtest");

    try {
      mobilePlayInstalled = await MobilePay().isMobilePayInstalled;
    } on PlatformException {
      mobilePlayInstalled = false;
    }

    if (!mounted) return;

    setState(() {
      _mobilePlayInstalled = mobilePlayInstalled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Mobile Pay Example'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text('Mobile Pay Installed: $_mobilePlayInstalled\n'),
              FlatButton(
                child: Text("Pay"),
                onPressed: initiatePayment,
              ),
              if (_loading) CircularProgressIndicator(),
              if (_paymentResult != null) buildPaymentResult()
            ],
          ),
        ),
      ),
    );
  }

  initiatePayment() async {
    if (_mobilePlayInstalled) {
      setState(() {
        _loading = true;
      });
      try {
        final result = await MobilePay()
            .createPayment(productPrice: 10.5, orderId: "fkjgjkdffgdj");
        setState(() {
          _paymentResult = result;
        });
      } catch (e) {
        print(e);
      } finally {
        setState(() {
          _loading = false;
        });
      }
    } else
      await MobilePay().downloadMobilePay();
  }

  Widget buildPaymentResult() {
    if (_paymentResult.isCanceled)
      return Text(
        "Transaction canceled",
        style: Theme.of(context).textTheme.display2,
      );
    if (_paymentResult.isFailure)
      return Column(
        children: <Widget>[
          Text(
            "Transaction failure",
            style: Theme.of(context).textTheme.display2,
          ),
          Text("${_paymentResult.errorCode}: ${_paymentResult.errorMessage}")
        ],
      );

    return Column(
      children: <Widget>[
        Text(
          "Transaction successfully done",
          style: Theme.of(context).textTheme.display2,
        ),
        Text("${_paymentResult.amountWithdrawnFromCard} €"),
        Text("${_paymentResult.orderId}"),
        Text("${_paymentResult.transactionId}"),
      ],
    );
  }
}
