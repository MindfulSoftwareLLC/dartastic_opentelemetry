import 'package:http/http.dart' as http;

class OtlpHttpException extends http.ClientException {
  final int statusCode;

  OtlpHttpException(String message, this.statusCode, [Uri? uri])
      : super(message, uri);

}