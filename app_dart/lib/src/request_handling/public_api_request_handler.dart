// Copyright 2019 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

import 'exceptions.dart';
import 'request_handler.dart';

/// A [RequestHandler] for public APIs that do not require authentication.
abstract base class PublicApiRequestHandler extends RequestHandler {
  /// Creates a new [PublicApiRequestHandler].
  const PublicApiRequestHandler({required super.config});

  /// Throws a [BadRequestException] if any of [requiredParameters] is missing
  /// from [requestData].
  @protected
  void checkRequiredParameters(
    Map<String, Object?> requestData,
    List<String> requiredParameters,
  ) {
    final Iterable<String> missingParams = requiredParameters
      ..removeWhere(requestData.containsKey);
    if (missingParams.isNotEmpty) {
      throw BadRequestException(
        'Missing required parameter: ${missingParams.join(', ')}',
      );
    }
  }

  /// Throws a [BadRequestException] if any of [requiredQueryParameters] are missing from [requestData].
  @protected
  void checkRequiredQueryParameters(
    Request request,
    List<String> requiredQueryParameters,
  ) {
    final Iterable<String> missingParams = requiredQueryParameters
      ..removeWhere(request.uri.queryParameters.containsKey);
    if (missingParams.isNotEmpty) {
      throw BadRequestException(
        'Missing required parameter: ${missingParams.join(', ')}',
      );
    }
  }
}
