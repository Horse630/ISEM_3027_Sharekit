import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'text.dart';

class OpeningPage extends StatefulWidget {
  const OpeningPage({super.key});

  @override
  State<OpeningPage> createState() => _OpeningPageState();
}

class _OpeningPageState extends State<OpeningPage> with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF003070),
      body: Center(
        child: AnimatedBuilder(
          animation: _motion,
          builder: (context, _) {
            final pulse = 0.94 + 0.06 * math.sin(_motion.value * math.pi * 2);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 168,
                  height: 168,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.rotate(
                        angle: _motion.value * math.pi * 2,
                        child: const CustomPaint(
                          size: Size.square(168),
                          painter: _OpeningRingPainter(),
                        ),
                      ),
                      Transform.scale(
                        scale: pulse,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Image.asset(
                            'assets/app_icon.png',
                            width: 112,
                            height: 112,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'ShareKit',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr(context, '正在開啟', 'Opening'),
                  style: const TextStyle(
                    color: Color(0xFF9CC4EE),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OpeningRingPainter extends CustomPainter {
  const _OpeningRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF8ECAFF);
    final rect = Rect.fromLTWH(8, 8, size.width - 16, size.height - 16);
    canvas.drawArc(rect, -0.4, 1.6, false, paint);
    canvas.drawArc(rect, 2.6, 1.15, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
