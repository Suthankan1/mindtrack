import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mindtrack_mobile/main.dart';
import 'package:mindtrack_mobile/navigation/bottom_nav_bar.dart';

void main() {
  testWidgets('Sanctuary App Bootstrapping and Custom Nav Rendering Smoke Test', (WidgetTester tester) async {
    // Build our app wrapped in ProviderScope (required for Riverpod) and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: MindTrackApp(),
      ),
    );

    // Let the go_router transitions settle
    await tester.pumpAndSettle();

    // Verify that our custom BottomNavBar is rendered in the view hierarchy
    expect(find.byType(CustomBottomNavBar), findsOneWidget);

    // Verify that the greeting headline exists on the Home page
    expect(find.text('MindTracker'), findsOneWidget);
    expect(find.text('Current Streak'), findsOneWidget);
  });
}
