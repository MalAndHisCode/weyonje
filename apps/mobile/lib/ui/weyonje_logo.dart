import 'package:flutter/widgets.dart';

class WeyonjeLogo extends StatelessWidget {
  const WeyonjeLogo({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth.clamp(0.0, 280.0);
      return Semantics(
        image: true,
        label: 'Weyonje',
        child: ExcludeSemantics(
          child: Image.asset(
            'assets/branding/weyonje-logo.png',
            width: width,
            height: width,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      );
    },
  );
}
