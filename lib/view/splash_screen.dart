import 'package:flutter/material.dart';
import 'dart:async';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Timer(Duration(seconds: 5), () {
      Navigator.pushReplacementNamed(context, '/home');
    });

    return Container(
      color: const Color.fromRGBO(11, 18, 34, 1.0),
      child: Center(
        child: Image.asset(
          'assets/logo.png',
          width: 500,
          height: 500,
        ),
      ),
    );
  }
}
