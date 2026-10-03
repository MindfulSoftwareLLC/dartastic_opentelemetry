import 'package:http/http.dart' as http;

class OtlpHttpException extends http.ClientException {
  final int statusCode;

  OtlpHttpException(super.message, this.statusCode, [super.uri]);
}
