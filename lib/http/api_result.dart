enum ApiFailureKind {
  network,
  timeout,
  cancelled,
  httpStatus,
  apiRejected,
  malformedResponse,
  decoding,
  unknown,
}

sealed class ApiResult<T> {
  const ApiResult();

  int? get statusCode;

  bool get isSuccess => this is ApiSuccess<T>;

  R fold<R>({
    required R Function(T data) success,
    required R Function(ApiFailure<T> failure) failure,
  }) {
    return switch (this) {
      ApiSuccess<T>(:final data) => success(data),
      final ApiFailure<T> value => failure(value),
    };
  }

  ApiResult<R> map<R>(R Function(T data) transform) {
    return switch (this) {
      ApiSuccess<T>(:final data, :final statusCode) => ApiSuccess<R>(
        transform(data),
        statusCode: statusCode,
      ),
      final ApiFailure<T> value => value.cast<R>(),
    };
  }
}

final class ApiSuccess<T> extends ApiResult<T> {
  const ApiSuccess(this.data, {this.statusCode});

  final T data;

  @override
  final int? statusCode;
}

final class ApiFailure<T> extends ApiResult<T> {
  const ApiFailure({
    required this.kind,
    required this.message,
    this.endpoint,
    this.statusCode,
    this.apiCode,
    this.retryable = false,
  });

  final ApiFailureKind kind;
  final String message;
  final String? endpoint;

  @override
  final int? statusCode;

  final int? apiCode;
  final bool retryable;

  ApiFailure<R> cast<R>() => ApiFailure<R>(
    kind: kind,
    message: message,
    endpoint: endpoint,
    statusCode: statusCode,
    apiCode: apiCode,
    retryable: retryable,
  );

  @override
  String toString() {
    return 'ApiFailure(kind: $kind, endpoint: $endpoint, '
        'statusCode: $statusCode, apiCode: $apiCode, retryable: $retryable)';
  }
}
