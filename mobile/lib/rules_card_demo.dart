import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Public card reveals demonstrating two misses followed by a successful trio.
class RulesCardDemo extends StatefulWidget {
  const RulesCardDemo({super.key});

  @override
  State<RulesCardDemo> createState() => _RulesCardDemoState();
}

class _RulesCardDemoState extends State<RulesCardDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 15),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final seconds = _controller.value * 15;
      final phase = (seconds / 5).floor().clamp(0, 2);
      final time = seconds - phase * 5;
      final values = const [[1, 2, 7], [2, 2, 7], [5, 5, 5]][phase];
      final count = phase == 0 ? 2 : 3;
      final resolved = time >= (count == 2 ? 1.8 : 2.4) && time < 4.1;
      final success = phase == 2 && resolved;
      final label = resolved
          ? (success ? '✓ TRIO! Három egyforma – ez a jó megoldás!' : '✕ Eltérő lapok – a kör véget ér')
          : 'Fordíts fel három azonos értékű lapot';
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 110,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                final start = 0.4 + index * 0.65;
                final opening = ((time - start) / 0.4).clamp(0.0, 1.0);
                final closing = ((time - 4.1) / 0.45).clamp(0.0, 1.0);
                final flip = index < count ? opening * (1 - closing) : 0.0;
                final front = flip >= 0.5;
                final widthScale = math.cos(flip * math.pi).abs().clamp(0.01, 1.0);
                final bounce = success ? math.sin(((time - 2.4) / 0.65).clamp(0.0, 1.0) * math.pi) * 12 : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Transform.translate(
                    offset: Offset(0, -bounce),
                    child: Transform.scale(
                      scale: success ? 1.08 : 1,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.diagonal3Values(widthScale, 1, 1),
                        child: Container(
                          width: 62,
                          height: 88,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: success ? const [BoxShadow(color: Color(0xffb6ef45), blurRadius: 12)] : null,
                          ),
                          child: Image.asset(
                            'assets/cards_new/${front ? values[index] : 'back'}.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          SizedBox(
            height: 38,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: resolved ? (success ? const Color(0xffb6ef45) : const Color(0xffffb4a5)) : const Color(0xfffff0c7),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    },
  );
}
