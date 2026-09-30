import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:e2ee_notes/exchange/exchange_client.dart';

void main() {
  test('uploads a payload and returns the transfer url', () async {
    final client = ExchangeClient(
      baseUrl: 'https://exchange.example.com',
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://exchange.example.com/v1/transfers',
        );
        expect(request.body, 'payload');
        return http.Response(
          '{"url":"https://exchange.example.com/v1/transfers/abc",'
          '"expiresAt":"2026-09-30T12:00:00Z"}',
          201,
        );
      }),
    );

    final transfer = await client.upload('payload');
    expect(transfer.url, 'https://exchange.example.com/v1/transfers/abc');
    expect(transfer.expiresAt, '2026-09-30T12:00:00Z');
  });

  test('downloads a payload from a url', () async {
    final client = ExchangeClient(
      baseUrl: 'https://exchange.example.com',
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.toString(),
          'https://exchange.example.com/v1/transfers/abc',
        );
        return http.Response('payload', 200);
      }),
    );

    expect(
      await client.download('https://exchange.example.com/v1/transfers/abc'),
      'payload',
    );
  });

  test('non-2xx responses throw ExchangeException', () async {
    final client = ExchangeClient(
      baseUrl: 'https://exchange.example.com',
      client: MockClient(
        (request) async => http.Response('{"error":"not_found"}', 404),
      ),
    );

    await expectLater(client.upload('x'), throwsA(isA<ExchangeException>()));
    await expectLater(
      client.download('https://exchange.example.com/v1/transfers/abc'),
      throwsA(isA<ExchangeException>()),
    );
  });
}
