part of 'logger_provider.dart';

/// Factory for creating LoggerProvider instances.
///
/// This factory class provides a static create method for constructing
/// properly configured LoggerProvider instances. It follows the factory
/// pattern to separate the construction logic from the LoggerProvider
/// class itself.
class SDKLoggerProviderCreate {
  /// Creates a new LoggerProvider with the specified delegate and resource.
  static LoggerProvider create(
      {required APILoggerProvider delegate, Resource? resource}) {
    return LoggerProvider._(delegate: delegate, resource: resource);
  }
}
