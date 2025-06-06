// Copyright 2019 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io' if (kIsWeb) '';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'service/cocoon.dart';
import 'service/firebase_auth.dart';
import 'state/build.dart';
import 'views/build_dashboard_page.dart';
import 'views/tree_status_page.dart';
import 'widgets/now.dart';
import 'widgets/state_provider.dart';
import 'widgets/task_box.dart';

void usage() {
  // ignore: avoid_print
  print('''
Usage: cocoon [--use-production-service | --no-use-production-service]

  --[no-]use-production-service  Enable/disable using the production Cocoon
                                 service for source data. Defaults to the
                                 production service in a release build, and the
                                 fake service in a debug build.
''');
}

void main([List<String> args = const <String>[]]) async {
  var useProductionService = kReleaseMode;
  if (args.contains('--help')) {
    usage();
    if (!kIsWeb) {
      exit(0);
    }
  }
  if (args.contains('--use-production-service')) {
    useProductionService = true;
  }
  if (args.contains('--no-use-production-service')) {
    useProductionService = false;
  }
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kReleaseMode) {
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };
    // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  final authService = FirebaseAuthService();

  final cocoonService = CocoonService(
    useProductionService: useProductionService,
  );
  runApp(
    StateProvider(
      signInService: authService,
      buildState: BuildState(
        authService: authService,
        cocoonService: cocoonService,
      ),
      child: Now(child: const MyApp()),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return TaskBox(
      child: MaterialApp(
        title: 'Flutter Build Dashboard — Cocoon',
        shortcuts: {
          ...WidgetsApp.defaultShortcuts,
          const SingleActivator(LogicalKeyboardKey.select):
              const ActivateIntent(),
        },
        theme: ThemeData(
          useMaterial3: false,
          primaryTextTheme: const TextTheme(
            bodyLarge: TextStyle(color: Colors.black87),
          ),
        ),
        darkTheme: ThemeData.dark(),

        // The default page is the build dashboard.
        initialRoute: BuildDashboardPage.routeName,
        routes: {
          BuildDashboardPage.routeName: (_) => const BuildDashboardPage(),
        },

        // dashboard.com/x/flutter/flutter/presubmit
        // jonahwilliams@ [1234] > .../1234
        // matanlurey@    [4568] > .../4567
        //
        // dashboard.com/x/flutter/flutter/presubmit/1234
        onGenerateRoute: (RouteSettings settings) {
          final uriData = Uri.parse(settings.name!);
          if (uriData.pathSegments.isEmpty) {
            return null;
          }

          switch (uriData.pathSegments.first) {
            case BuildDashboardPage.routeSegment:
              return MaterialPageRoute(
                settings: settings,
                builder: (_) {
                  return BuildDashboardPage(
                    queryParameters: uriData.queryParameters,
                  );
                },
              );
            case TreeStatusPage.routeSegment:
              return MaterialPageRoute(
                settings: settings,
                builder: (_) {
                  return TreeStatusPage(
                    queryParameters: uriData.queryParameters,
                  );
                },
              );
          }
          return null;
        },
      ),
    );
  }
}
