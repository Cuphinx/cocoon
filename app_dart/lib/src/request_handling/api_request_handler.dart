// Copyright 2019 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'authentication.dart';
import 'exceptions.dart';
import 'public_api_request_handler.dart';
import 'request_handler.dart';

/// A [RequestHandler] that handles API requests.
///
/// API requests adhere to a specific contract, as follows:
///
///  * All requests must be authenticated per [AuthenticationProvider].
abstract base class ApiRequestHandler extends PublicApiRequestHandler {
  /// Creates a new [ApiRequestHandler].
  const ApiRequestHandler({
    required super.config,
    required this.authenticationProvider,
  });

  /// Service responsible for authenticating this [HttpRequest].
  @protected
  final AuthenticationProvider authenticationProvider;

  /// The authentication context associated with the HTTP request.
  ///
  /// This is guaranteed to be non-null. If the request was unauthenticated,
  /// the request will be denied.
  @protected
  AuthenticatedContext? get authContext =>
      getValue<AuthenticatedContext>(ApiKey.authContext);

  @override
  Future<void> service(
    HttpRequest request, {
    Future<void> Function(HttpStatusException)? onError,
  }) async {
    AuthenticatedContext context;
    try {
      context = await authenticationProvider.authenticate(request);
    } on Unauthenticated catch (error) {
      final response = request.response;
      response
        ..statusCode = HttpStatus.unauthorized
        ..write(error.message);
      await response.flush();
      await response.close();
      return;
    }

    await runZoned<Future<void>>(() async {
      await super.service(request);
    }, zoneValues: <ApiKey<dynamic>, Object?>{ApiKey.authContext: context});
  }
}

class ApiKey<T> extends RequestKey<T> {
  const ApiKey._(super.name);

  static const ApiKey<Uint8List> requestBody = ApiKey<Uint8List>._(
    'requestBody',
  );
  static const ApiKey<AuthenticatedContext> authContext =
      ApiKey<AuthenticatedContext>._('authenticatedContext');
  static const ApiKey<Map<String, dynamic>> requestData =
      ApiKey<Map<String, dynamic>>._('requestData');
}
