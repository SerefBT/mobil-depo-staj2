import 'package:dio/dio.dart';

import '../models/models.dart';

class ApiFailure implements Exception {
  final String message;
  final int? status;
  const ApiFailure(this.message, [this.status]);
  @override
  String toString() => message;
}

class ApiService {
  final Dio dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 25),
      sendTimeout: const Duration(seconds: 20),
    ),
  );
  String? token;
  void Function()? onUnauthorized;
  ApiService() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          if (token != null) o.headers['Authorization'] = 'Bearer $token';
          h.next(o);
        },
        onError: (e, h) {
          if (e.response?.statusCode == 401 && token != null) {
            onUnauthorized?.call();
          }
          h.next(e);
        },
      ),
    );
  }
  void configure(String url) =>
      dio.options.baseUrl = url.replaceFirst(RegExp(r'/+$'), '');
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    ResponseType? responseType,
  }) async {
    try {
      return (await dio.request<dynamic>(
        path,
        data: data,
        queryParameters: query,
        options: Options(method: method, responseType: responseType),
      )).data;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      final body = e.response?.data;
      final title = body is Map ? body['title']?.toString() : null;
      throw ApiFailure(
        title ??
            (code == 401
                ? 'Oturumunuz sona erdi veya giriş bilgileri hatalı.'
                : code == 403
                ? 'Bu işlem için yetkiniz bulunmuyor.'
                : code == 429
                ? 'Çok fazla deneme yapıldı. Bir dakika sonra tekrar deneyin.'
                : code != null
                ? 'Sunucu işlemi tamamlayamadı ($code).'
                : 'Sunucuya ulaşılamadı. API adresini ve bağlantınızı kontrol edin.'),
        code,
      );
    }
  }

  Future<Json> get(String path, {Map<String, dynamic>? query}) async =>
      asJson(await request('GET', path, query: query));
  Future<List<Json>> list(String path, {Map<String, dynamic>? query}) async =>
      asList(await request('GET', path, query: query));
  Future<dynamic> post(String path, dynamic data) =>
      request('POST', path, data: data);
  Future<dynamic> put(String path, [dynamic data]) =>
      request('PUT', path, data: data);
  Future<List<Json>> allProducts() async {
    final items = <Json>[];
    var page = 1;
    while (true) {
      final result = await get(
        '/products',
        query: {'page': page, 'pageSize': 100},
      );
      final rows = asList(result['items']);
      items.addAll(rows);
      if (items.length >= result.n('total') || rows.isEmpty) break;
      page++;
    }
    return items;
  }
}
