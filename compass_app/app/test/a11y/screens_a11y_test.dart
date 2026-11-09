// Accessibility audit of every screen (flutter_a11y_test, layer "runtime").
//
// Pumps the real app shell with the real go_router and the sample's own test
// fakes (the same ones its widget tests use — synchronous, no asset IO), visits
// each route, and runs the audit battery. Findings are RECORDED, not asserted:
// the RuntimeFindingsSink in flutter_test_config.dart writes them to
// .a11y/flutter/runtime-findings.json and `a11y_check_flutter scan` decides,
// against the committed baseline, what fails CI.
import 'dart:async';
import 'dart:io';

import 'package:compass_app/data/repositories/activity/activity_repository.dart';
import 'package:compass_app/data/repositories/auth/auth_repository.dart';
import 'package:compass_app/data/repositories/booking/booking_repository.dart';
import 'package:compass_app/data/repositories/continent/continent_repository.dart';
import 'package:compass_app/data/repositories/destination/destination_repository.dart';
import 'package:compass_app/data/repositories/itinerary_config/itinerary_config_repository.dart';
import 'package:compass_app/data/repositories/user/user_repository.dart';
import 'package:compass_app/domain/models/itinerary_config/itinerary_config.dart';
import 'package:compass_app/domain/use_cases/booking/booking_create_use_case.dart';
import 'package:compass_app/domain/use_cases/booking/booking_share_use_case.dart';
import 'package:compass_app/routing/router.dart';
import 'package:compass_app/routing/routes.dart';
import 'package:compass_app/ui/search_form/widgets/search_form_guests.dart';
import 'package:compass_app/ui/core/localization/applocalization.dart';
import 'package:compass_app/ui/core/themes/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_a11y_test/flutter_a11y_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail_image_network/mocktail_image_network.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../testing/fakes/repositories/fake_activities_repository.dart';
import '../../testing/fakes/repositories/fake_auth_repository.dart';
import '../../testing/fakes/repositories/fake_booking_repository.dart';
import '../../testing/fakes/repositories/fake_continent_repository.dart';
import '../../testing/fakes/repositories/fake_destination_repository.dart';
import '../../testing/fakes/repositories/fake_itinerary_config_repository.dart';
import '../../testing/fakes/repositories/fake_user_repository.dart';
import '../../testing/models/booking.dart';
import '../../testing/models/destination.dart';

/// A complete itinerary (matching the fakes' data) so results, activities and
/// booking render real content rather than an empty state.
final ItineraryConfig _fullConfig = ItineraryConfig(
  continent: 'Europe',
  startDate: DateTime(2024, 1, 1),
  endDate: DateTime(2024, 2, 1),
  guests: 2,
  destination: kDestination1.ref,
  activities: const ['ACTIVITY-REF'],
);

/// The sample's own fakes, wired the way its widget tests wire them.
List<SingleChildWidget> _fakeProviders(
  AuthRepository auth, {
  ItineraryConfig? config,
}) {
  final bookings = FakeBookingRepository()..createBooking(kBooking);
  return [
    ChangeNotifierProvider<AuthRepository>.value(value: auth),
    Provider<DestinationRepository>(create: (_) => FakeDestinationRepository()),
    Provider<ContinentRepository>(create: (_) => FakeContinentRepository()),
    Provider<ActivityRepository>(create: (_) => FakeActivityRepository()),
    Provider<BookingRepository>.value(value: bookings),
    Provider<ItineraryConfigRepository>(
      create: (_) => FakeItineraryConfigRepository(itineraryConfig: config),
    ),
    Provider<UserRepository>(create: (_) => FakeUserRepository()),
    Provider(
      create: (context) => BookingCreateUseCase(
        destinationRepository: context.read(),
        activityRepository: context.read(),
        bookingRepository: context.read(),
      ),
    ),
    Provider(create: (_) => BookingShareUseCase.custom((text) async {})),
  ];
}

Future<void> _audit(
  WidgetTester tester,
  String screenId, {
  String? location,
  bool loggedIn = true,
  ItineraryConfig? config,
}) async {
  // google_fonts loads fonts fire-and-forget and rethrows when a font is neither
  // bundled nor fetchable (see setUpAll); under flutter_test that uncaught async
  // error would fail the test. Pump and audit inside a guarded zone: exactly
  // those errors are dropped, anything else is handed to the framework's test
  // handler and fails the test as usual.
  final done = Completer<void>();
  runZonedGuarded(
    () => _pumpAndAudit(
      tester,
      screenId,
      location: location,
      loggedIn: loggedIn,
      config: config,
    ).then(done.complete, onError: done.completeError),
    (error, stack) {
      if ('$error'.contains('GoogleFonts')) return;
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack),
      );
    },
  );
  await done.future;
}

Future<void> _pumpAndAudit(
  WidgetTester tester,
  String screenId, {
  String? location,
  bool loggedIn = true,
  ItineraryConfig? config,
}) async {
  await mockNetworkImages(() async {
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = FakeAuthRepository();
    if (loggedIn) auth.token = 'TOKEN';
    final goRouter = router(auth);
    await tester.pumpWidget(
      MultiProvider(
        providers: _fakeProviders(auth, config: config),
        child: MaterialApp.router(
          localizationsDelegates: [
            GlobalWidgetsLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            AppLocalizationDelegate(),
          ],
          theme: AppTheme.lightTheme,
          routerConfig: goRouter,
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (location != null) {
      goRouter.go(location);
      await tester.pumpAndSettle();
    }
    final result = await auditScreen(tester, screenId: screenId);
    // ignore: avoid_print
    print(
      'a11y $screenId at ${goRouter.routerDelegate.currentConfiguration.uri}: '
      '${result.findings.length} finding(s)',
    );
  });
}

void main() {
  setUp(() {
    // cached_network_image's cache manager asks path_provider for a directory;
    // there is no platform plugin under `flutter test`, so answer it ourselves.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async =>
              Directory.systemTemp.createTempSync('compass-a11y-').path,
        );
  });

  setUpAll(() {
    // The theme uses google_fonts, which fetches font files over HTTP at runtime;
    // under `flutter test` that fetch would get the image mock's fake bytes. With
    // fetching off and no bundled font, text renders in the test's default font
    // (the audit's own diagnostic notes that text metrics differ from a device).
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('login', (tester) async {
    // Logged out: the router redirects the initial location to /login.
    await _audit(tester, 'login', loggedIn: false);
  });

  testWidgets('home', (tester) async {
    await _audit(tester, 'home');
  });

  testWidgets('search', (tester) async {
    await _audit(tester, 'search', location: Routes.search);
  });

  testWidgets('results', (tester) async {
    await _audit(
      tester,
      'results',
      location: Routes.results,
      config: _fullConfig,
    );
  });

  testWidgets('activities', (tester) async {
    await _audit(
      tester,
      'activities',
      location: Routes.activities,
      config: _fullConfig,
    );
  });

  testWidgets('booking (new, from the itinerary)', (tester) async {
    await _audit(
      tester,
      'booking',
      location: Routes.booking,
      config: _fullConfig,
    );
  });

  testWidgets('booking (existing, by id)', (tester) async {
    await _audit(tester, 'booking/:id', location: Routes.bookingWithId(0));
  });

  testWidgets('search, after adding a guest (interaction: live region)', (
    tester,
  ) async {
    // missing-live-region only runs against a before-change snapshot: audit the
    // search form once more after tapping "add guest", under its own screen id.
    final done = Completer<void>();
    runZonedGuarded(
      () => mockNetworkImages(() async {
        tester.view.devicePixelRatio = 1.0;
        await tester.binding.setSurfaceSize(const Size(1200, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final auth = FakeAuthRepository()..token = 'TOKEN';
        final goRouter = router(auth);
        await tester.pumpWidget(
          MultiProvider(
            providers: _fakeProviders(auth),
            child: MaterialApp.router(
              localizationsDelegates: [
                GlobalWidgetsLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                AppLocalizationDelegate(),
              ],
              theme: AppTheme.lightTheme,
              routerConfig: goRouter,
            ),
          ),
        );
        await tester.pumpAndSettle();
        goRouter.go(Routes.search);
        await tester.pumpAndSettle();
        final before = await A11ySnapshot.capture(tester);
        await tester.tap(find.byKey(const ValueKey(addGuestsKey)));
        await tester.pump();
        // Only the interaction rule: the search form's other findings are already
        // recorded under `search`, and a second screen id would duplicate them.
        final result = await auditScreen(
          tester,
          screenId: 'search/add-guest',
          beforeChange: before,
          config: const A11yAuditConfig(rules: {RuleIds.missingLiveRegion}),
        );
        // ignore: avoid_print
        print('a11y search/add-guest: ${result.findings.length} finding(s)');
      }).then(done.complete, onError: done.completeError),
      (error, stack) {
        if ('$error'.contains('GoogleFonts')) return;
        FlutterError.reportError(
          FlutterErrorDetails(exception: error, stack: stack),
        );
      },
    );
    await done.future;
  });
}
