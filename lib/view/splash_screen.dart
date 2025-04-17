import 'package:flutter/material.dart';
import 'dart:async';

late AnimationController _controller;
late Animation<double> _scaleAnimation;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _scaleAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();

    // Redireciona após 5 segundos
    Timer(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Mantém o precacheImage aqui para garantir que a imagem esteja pronta
    precacheImage(const AssetImage('assets/logo_tiny.png'), context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color.fromRGBO(11, 18, 34, 1.0),
      child: Center(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Image.asset(
            'assets/logo_tiny.png',
            width: 500,
            height: 500,
          ),
        ),
      ),
    );
  }
}
