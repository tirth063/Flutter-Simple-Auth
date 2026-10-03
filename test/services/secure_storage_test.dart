import 'package:flutter_test/flutter_test.dart';
import 'package:mainapp/services/secure_storage.dart';

void main() {
  group("getTokenExpiry", () {
    test("returns expiry from valid JWT", () {
      // JWT: {"exp": 1700000000}
      final token =
          "eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjE3MDAwMDAwMDB9.abc123";
      final exp = getTokenExpiry(token);
      expect(exp, 1700000000);
    });

    test("returns null for token with no exp claim", () {
      // JWT: {"sub": "test"}
      final token =
          "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ0ZXN0In0.abc123";
      final exp = getTokenExpiry(token);
      expect(exp, isNull);
    });

    test("returns null for malformed token", () {
      expect(getTokenExpiry("not-a-jwt"), isNull);
      expect(getTokenExpiry(""), isNull);
    });

    test("returns null for token with invalid base64", () {
      expect(getTokenExpiry("a.b@#c.c"), isNull);
    });
  });
}
