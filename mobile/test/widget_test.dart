import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mobil_depo/models/models.dart';
import 'package:mobil_depo/providers/app_state.dart';
import 'package:mobil_depo/screens/login_screen.dart';
import 'package:mobil_depo/screens/dashboard_screen.dart';
import 'package:mobil_depo/screens/products_screen.dart';
import 'package:mobil_depo/screens/requests_screen.dart';
import 'package:mobil_depo/screens/shell_screen.dart';
import 'package:mobil_depo/theme/app_theme.dart';
import 'package:mobil_depo/utils/format.dart';

class FakeAdapter implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options);
    final dynamic data = switch (options.uri.path) {
      '/api/dashboard' => {
        'totalProducts': 20,
        'totalStock': 2443,
        'criticalStock': 4,
        'pendingRequests': 8,
        'todayIn': 145,
        'todayOut': 97,
        'criticalProducts': <dynamic>[],
        'recentMovements': <dynamic>[],
      },
      '/api/products' => {'total': 0, 'items': <dynamic>[]},
      '/api/categories' => [
        {'id': 1, 'name': 'Sarf Malzeme'},
      ],
      '/api/shelves' => [
        {'id': 7, 'code': 'B04', 'warehouse': 'A Deposu', 'aisle': 'Koridor 2'},
      ],
      '/api/requests' => {'total': 0, 'items': <dynamic>[]},
      _ => <dynamic>[],
    };
    return ResponseBody.fromString(
      jsonEncode(data),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

AppState app(String role, FakeAdapter adapter) {
  final state = AppState();
  state.starting = false;
  state.api.configure('http://test/api');
  state.api.dio.httpClientAdapter = adapter;
  state.user = UserProfile(
    id: 'test',
    email: 'demo@local',
    fullName: 'Demo Personel',
    role: role,
    unit: 'İdari Hizmetler',
    unitId: 1,
  );
  return state;
}

Future<void> mount(
  WidgetTester tester,
  AppState state,
  Widget widget, {
  double width = 390,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(theme: AppTheme.create(false), home: widget),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('Türkçe durum ve miktar biçimleri', () {
    expect(statusLabel('Preparing'), 'Hazırlanıyor');
    expect(movementLabel('Delivery'), 'Talep teslimi');
    expect(quantity(2443), '2.443');
    expect(positiveNumber('-1'), isNotNull);
    expect(positiveNumber('100'), isNull);
  });
  testWidgets('Giriş formu boş veriyi sunucuya göndermez', (tester) async {
    final adapter = FakeAdapter();
    final state = app('Warehouse', adapter);
    addTearDown(state.dispose);
    await mount(tester, state, const LoginScreen());
    await tester.ensureVisible(find.text('Giriş yap'));
    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();
    expect(find.text('Bu alan zorunludur.'), findsNWidgets(2));
    expect(adapter.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Dar telefonda dashboard taşmaz', (tester) async {
    final state = app('Warehouse', FakeAdapter());
    addTearDown(state.dispose);
    await mount(
      tester,
      state,
      const Scaffold(body: DashboardScreen()),
      width: 360,
    );
    expect(find.text('2.443'), findsOneWidget);
    expect(find.text('Bugünkü giriş'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Tablet dashboard düzeni taşmaz', (tester) async {
    final state = app('Admin', FakeAdapter());
    addTearDown(state.dispose);
    await mount(
      tester,
      state,
      const Scaffold(body: DashboardScreen()),
      width: 840,
    );
    expect(find.text('2.443'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Birim kullanıcısına depo işlem butonları gösterilmez', (
    tester,
  ) async {
    final state = app('Unit', FakeAdapter());
    addTearDown(state.dispose);
    await mount(tester, state, const ShellScreen());
    expect(find.byTooltip('QR / barkod tara'), findsNothing);
    expect(find.text('Stok girişi'), findsNothing);
    expect(find.text('Malzeme talep et'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Depo rolünde tarayıcı ve stok işlemleri görünür', (
    tester,
  ) async {
    final state = app('Warehouse', FakeAdapter());
    addTearDown(state.dispose);
    await mount(tester, state, const ShellScreen());
    expect(find.byTooltip('QR / barkod tara'), findsOneWidget);
    expect(find.text('Stok girişi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Ürün formu zorunlu alanları doğrular', (tester) async {
    final adapter = FakeAdapter();
    final state = app('Warehouse', adapter);
    addTearDown(state.dispose);
    await mount(tester, state, const ProductFormScreen());
    await tester.scrollUntilVisible(
      find.text('Ürünü kaydet'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Ürünü kaydet'));
    await tester.pumpAndSettle();
    expect(adapter.calls.where((c) => c.method == 'POST'), isEmpty);
    expect(find.text('Bir seçim yapın.'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Boş talep listesi açıklayıcı durum gösterir', (tester) async {
    final state = app('Unit', FakeAdapter());
    addTearDown(state.dispose);
    await mount(tester, state, const Scaffold(body: RequestsScreen()));
    expect(find.text('Talep bulunmuyor'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Masaüstü web menüsü geniş ekranda görünür', (tester) async {
    final state = app('Admin', FakeAdapter());
    addTearDown(state.dispose);
    await mount(tester, state, const ShellScreen(), width: 1440);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Raporlar ve SKT'), findsOneWidget);
    await tester.tap(find.text('Ürünler'));
    await tester.pumpAndSettle();
    expect(find.text('Ürün envanteri'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
