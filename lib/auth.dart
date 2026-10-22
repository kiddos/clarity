import 'dart:convert';

import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import 'constants.dart';
import 'log.dart';

Future<Map<String, dynamic>?> authenticate(final String baseUrl, final String launch) async {
  String authUrl = '$baseUrl/sim/$launch/auth/authorize';
  final String aud = '$baseUrl/sim/$launch/fhir';
  authUrl = Uri.parse(authUrl).replace(queryParameters: {
    'response_type': 'code',
    'client_id': kClientId,
    'redirect_uri': kRedirectUri,
    'scope': kScopes,
    'aud': aud,
  }).toString();

  try {
    log.i('auth url: $authUrl');
    final result = await FlutterWebAuth2.authenticate(
        url: authUrl,
        callbackUrlScheme: kCallbackScheme,
        options: const FlutterWebAuth2Options(preferEphemeral: true));
    log.i('result: $result');
    final uri = Uri.parse(result);
    final authCode = uri.queryParameters['code'];
    if (authCode != null) {
      return await exchangeCodeForToken(baseUrl, authCode);
    }
  } catch (e) {
    log.e('fail to authenticate', error: e);
  }
  return null;
}

Future<Map<String, dynamic>?> exchangeCodeForToken(String baseUrl, String authCode) async {
  final tokenUrl = '$baseUrl/auth/token';
  final response = await http.post(
    Uri.parse(tokenUrl),
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: {
      'grant_type': 'authorization_code',
      'code': authCode,
      'redirect_uri': kRedirectUri,
      'client_id': kClientId,
    },
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
  return null;
}
