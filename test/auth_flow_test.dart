import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:karum/main.dart';
import 'package:karum/src/api/gateway_client.dart';
import 'package:karum/src/auth/session_storage.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> _session({String token = 'tok-judge'}) => {
  'token': token,
  'account': {
    'id': 'acct-judge',
    'email': 'judge@karum.demo',
    'display_name': 'Karum Judge',
    'is_judge': true,
  },
};

class _AuthGateway {
  _AuthGateway({required this.hackathonMode, this.judgeStatus = 200});

  final bool hackathonMode;
  final int judgeStatus;
  final List<http.Request> requests = [];

  GatewayClient client() => GatewayClient(
    baseUrl: 'http://test',
    httpClient: MockClient((request) async {
      requests.add(request);
      final path = request.url.path;
      if (request.method == 'GET' && path == '/health') {
        return _json({
          'service': 'gateway',
          'status': 'ok',
          'mode': 'fixture',
          'version': 'test',
          'hackathon_mode': hackathonMode,
          'time': '2026-10-19T12:00:00Z',
        });
      }
      if (request.method == 'POST' && path == '/api/v1/auth/judge') {
        if (judgeStatus != 200) {
          return _json({
            'error': 'judge_not_configured',
            'message': 'judge access is unavailable',
          }, judgeStatus);
        }
        return _json(_session());
      }
      if (request.method == 'POST' && path == '/api/v1/auth/login') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (body['password'] != 'secret') {
          return _json({
            'error': 'invalid_credentials',
            'message': 'email or password is incorrect',
          }, 401);
        }
        return _json(_session(token: 'tok-password'));
      }
      if (request.method == 'GET' && path == '/api/v1/auth/me') {
        if (request.headers['Authorization'] != 'Bearer tok-judge') {
          return _json({'error': 'unauthorized'}, 401);
        }
        return _json({'account': _session()['account']});
      }
      if (request.method == 'POST' && path == '/api/v1/auth/logout') {
        return http.Response('', 204);
      }
      return http.Response('not found', 404);
    }),
  );
}

void _largeWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() => writeSessionToken(null));

  testWidgets('hackathon mode signs the judge in without a login wall', (
    tester,
  ) async {
    _largeWindow(tester);
    final gateway = _AuthGateway(hackathonMode: true);

    await tester.pumpWidget(KarumApp(client: gateway.client()));
    await tester.pumpAndSettle();

    expect(
      find.text('Try Sample: Sola Yuzu Mezcal in Austin, TX'),
      findsOneWidget,
    );
    expect(find.textContaining('Signed in as Karum Judge'), findsOneWidget);
    expect(find.textContaining('Judge mode'), findsOneWidget);
  });

  testWidgets(
    'hackathon mode off leaves the demo anonymous and hides the banner',
    (tester) async {
      _largeWindow(tester);
      final gateway = _AuthGateway(hackathonMode: false);

      await tester.pumpWidget(KarumApp(client: gateway.client()));
      await tester.pumpAndSettle();

      expect(
        find.text('Try Sample: Sola Yuzu Mezcal in Austin, TX'),
        findsOneWidget,
      );
      expect(find.textContaining('Signed in as Karum Judge'), findsNothing);
      expect(find.textContaining('Judge mode'), findsNothing);
      expect(
        gateway.requests.any((r) => r.url.path == '/api/v1/auth/judge'),
        isFalse,
      );
    },
  );

  testWidgets('email and password login opens the demo', (tester) async {
    _largeWindow(tester);
    final gateway = _AuthGateway(hackathonMode: false);

    await tester.pumpWidget(
      KarumApp(client: gateway.client(), initialRoute: '/login'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in to Karum.'), findsOneWidget);
    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), 'judge@karum.demo');
    await tester.enterText(fields.at(1), 'secret');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(
      gateway.requests.any((r) => r.url.path == '/api/v1/auth/login'),
      isTrue,
    );
    expect(
      find.text('Try Sample: Sola Yuzu Mezcal in Austin, TX'),
      findsOneWidget,
    );
  });

  testWidgets('invalid credentials stay on the login page with an error', (
    tester,
  ) async {
    _largeWindow(tester);
    final gateway = _AuthGateway(hackathonMode: false);

    await tester.pumpWidget(
      KarumApp(client: gateway.client(), initialRoute: '/login'),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'judge@karum.demo');
    await tester.enterText(fields.at(1), 'wrong');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('email or password is incorrect'), findsOneWidget);
    expect(find.text('Sign in to Karum.'), findsOneWidget);
  });

  testWidgets('a failed auto judge login leaves the demo anonymous', (
    tester,
  ) async {
    _largeWindow(tester);
    final gateway = _AuthGateway(hackathonMode: true, judgeStatus: 503);

    await tester.pumpWidget(KarumApp(client: gateway.client()));
    await tester.pumpAndSettle();

    expect(
      find.text('Try Sample: Sola Yuzu Mezcal in Austin, TX'),
      findsOneWidget,
    );
    expect(find.textContaining('Hackathon judge access is on'), findsOneWidget);
    expect(find.text('Sign in to Karum.'), findsNothing);
  });
}
