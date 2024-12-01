import 'package:flutter/material.dart';

BoxDecoration my_decoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(10),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(0.2),
      spreadRadius: 1,
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ],
);

class FadingTextLoading extends StatefulWidget {
  @override
  _FadingTextLoadingState createState() => _FadingTextLoadingState();
}

class _FadingTextLoadingState extends State<FadingTextLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 150,
        height: 100,
        decoration: my_decoration,
        child: Center(
          child: FadeTransition(
            opacity: _animation,
            child: const Text(
              "Loading",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
