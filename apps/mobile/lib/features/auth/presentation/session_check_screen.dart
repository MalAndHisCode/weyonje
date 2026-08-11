import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../ui/weyonje_page.dart';

class SessionCheckScreen extends StatelessWidget {
  const SessionCheckScreen({super.key});

  @override
  Widget build(BuildContext context) => WeyonjePage(
    centerVertically: true,
    child: Semantics(
      container: true,
      liveRegion: true,
      label: 'Checking your Weyonje session',
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 180,
            child: FProgress(semanticsLabel: 'Checking your Weyonje session'),
          ),
          SizedBox(height: 20),
          Text('Checking your session…', textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
