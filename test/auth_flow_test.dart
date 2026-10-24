import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:karum/main.dart';
import 'package:karum/src/api/gateway_client.dart';
import 'package:karum/src/auth/session_storage.dart';

import 'support/fake_gateway.dart' show presetsJson;

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
      if (request.method == 'GET' && path == '/api/v1/presets') {
        return _json(presetsJson());
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
      if (request.method == 'POST' && path == '/api/v1/auth/register') {
        return _json({
          'token': 'tok-owner',
          'account': {
            'id': 'acct-owner',
            'email': 'owner@example.com',
            'display_name': 'owner',
            'is_judge': false,
          },
        }, 201);
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

  testWidgets('the public demo stays anonymous until someone signs in', (
    tester,
  ) async {
    _largeWindow(tester);
    final gateway = _AuthGateway(hackathonMode: true);

    await tester.pumpWidget(KarumApp(client: gateway.client()));
    await tester.pumpAndSettle();

    expect(
      find.text('Sola Yuzu Mezcal in Austin, TX'),
      findsOneWidget,
    );
    expect(find.textContaining('Signed in as'), findsNothing);
    expect(find.textContaining('Judge mode'), findsNothing);
    expect(
      gateway.requests.any((r) => r.url.path == '/api/v1/auth/judge'),
      isFalse,
    );
  });

  testWidgets('the landing offers a sign-in entry that opens the login page', (
    tester,
  ) async {
    _largeWindow(tester);
    final gateway = _AuthGateway(hackathonMode: false);

    await tester.pumpWidget(KarumApp(client: gateway.client()));
    await tester.pumpAndSettle();

    // Anonymous by default: the landing never shows a form, only the entry.
    expect(find.text('Welcome back'), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('a restored session turns the landing entry into the account', (
    tester,
  ) async {
    _largeWindow(tester);
    writeSessionToken('tok-judge');
    final gateway = _AuthGateway(hackathonMode: true);

    await tester.pumpWidget(KarumApp(client: gateway.client()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Signed in as Karum Judge'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);

    await tester.tap(find.text('Your account'));
    await tester.pumpAndSettle();

    expect(find.text('YOUR CAMPAIGNS'), findsOneWidget);
    expect(find.text('Open campaign'), findsNWidgets(4));
  });

  testWidgets('the sign-in entry clears once a judge signs in', (tester) async {
    _largeWindow(tester);
    final gateway = _AuthGateway(hackathonMode: true);

    await tester.pumpWidget(
      KarumApp(client: gateway.client(), initialRoute: '/login'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Open demo'));
    await tester.pumpAndSettle();

    expect(find.text('Your account'), findsOneWidget);
    expect(find.textContaining('Signed in as'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('the judges banner opens the judge account', (tester) async {
    _largeWindow(tester);
    final gateway = _AuthGateway(hackathonMode: true);

    await tester.pumpWidget(
      KarumApp(client: gateway.client(), initialRoute: '/login'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hackathon judges'), findsOneWidget);
    expect(find.textContaining('pre-seeded demo'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Open demo'));
    await tester.pumpAndSettle();

    expect(
      gateway.requests.any((r) => r.url.path == '/api/v1/auth/judge'),
      isTrue,
    );
    expect(find.textContaining('Signed in as Karum Judge'), findsOneWidget);
    expect(find.text('YOUR CAMPAIGNS'), findsOneWidget);
    expect(find.text('Open campaign'), findsNWidgets(4));
  });

  testWidgets('the judge account opens a stored campaign', (tester) async {
    _largeWindow(tester);
    final gateway = _AuthGateway(hackathonMode: true);

    await tester.pumpWidget(
      KarumApp(client: gateway.client(), initialRoute: '/login'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Open demo'));
    await tester.pumpAndSettle();

    final open = find.widgetWithText(FilledButton, 'Open campaign').first;
    await tester.ensureVisible(open);
    await tester.tap(open);
    await tester.pumpAndSettle();

    expect(
      gateway.requests.any(
        (r) => r.url.path == '/api/v1/campaigns/cmp-austin-wholesale',
      ),
      isTrue,
    );
    expect(find.text('YOUR CAMPAIGNS'), findsNothing);
  });

  testWidgets('continue without signing in keeps the public demo open', (
    tester,
  ) async {
    _largeWindow(tester);
    final gateway = _AuthGateway(hackathonMode: true);

    await tester.pumpWidget(
      KarumApp(client: gateway.client(), initialRoute: '/login'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue without signing in'));
    await tester.pumpAndSettle();

    expect(
      find.text('Sola Yuzu Mezcal in Austin, TX'),
      findsOneWidget,
    );
    expect(
      gateway.requests.any((r) => r.url.path == '/api/v1/auth/judge'),
      isFalse,
    );
  });

  testWidgets('the judges banner hides when the build flag is off', (
    tester,
  ) async {
    _largeWindow(tester);
    final gateway = _AuthGateway(hackathonMode: true);

    await tester.pumpWidget(
      KarumApp(
        client: gateway.client(),
        initialRoute: '/login',
        showJudgesBanner: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Hackathon judges'), findsNothing);
    expect(find.text('Open demo'), findsNothing);
  });

  testWidgets('email and password login opens the account page', (
    tester,
  ) async {
    _largeWindow(tester);
    final gateway = _AuthGateway(hackathonMode: false);

    await tester.pumpWidget(
      KarumApp(
        client: gateway.client(),
        initialRoute: '/login',
        showJudgesBanner: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), 'judge@karum.demo');
    await tester.enterText(fields.at(1), 'secret');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    final login = gateway.requests.where(
      (r) => r.url.path == '/api/v1/auth/login',
    );
    expect(login, isNotEmpty);
    expect(jsonDecode(login.first.body)['email'], 'judge@karum.demo');
    expect(find.text('Your account'), findsOneWidget);
    expect(find.text('YOUR CAMPAIGNS'), findsOneWidget);
  });

  testWidgets('invalid credentials stay on the login page with an error', (
    tester,
  ) async {
    _largeWindow(tester);
    final gateway = _AuthGateway(hackathonMode: false);

    await tester.pumpWidget(
      KarumApp(
        client: gateway.client(),
        initialRoute: '/login',
        showJudgesBanner: false,
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'judge@karum.demo');
    await tester.enterText(fields.at(1), 'wrong');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('email or password is incorrect'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('a failed demo sign-in stays on the login page', (tester) async {
    _largeWindow(tester);
    final gateway = _AuthGateway(hackathonMode: true, judgeStatus: 503);

    await tester.pumpWidget(
      KarumApp(client: gateway.client(), initialRoute: '/login'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Open demo'));
    await tester.pumpAndSettle();

    expect(find.text('judge access is unavailable'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('creating an account signs in', (tester) async {
    _largeWindow(tester);
    final gateway = _AuthGateway(hackathonMode: false);

    await tester.pumpWidget(
      KarumApp(
        client: gateway.client(),
        initialRoute: '/login',
        showJudgesBanner: false,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    expect(find.text('Create an account'), findsWidgets);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'owner@example.com');
    await tester.enterText(fields.at(1), 'password1');
    await tester.enterText(fields.at(2), 'password1');
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Create account'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    final created = gateway.requests.where(
      (r) => r.url.path == '/api/v1/auth/register',
    );
    expect(created, isNotEmpty);
    final body = jsonDecode(created.first.body) as Map<String, dynamic>;
    expect(body['email'], 'owner@example.com');
    expect(body['password'], 'password1');
    expect(find.textContaining('Signed in as owner'), findsOneWidget);
    expect(find.text('No saved campaigns yet'), findsOneWidget);
  });
}
