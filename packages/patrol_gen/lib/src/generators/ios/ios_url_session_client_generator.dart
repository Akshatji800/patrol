import 'package:patrol_gen/src/generators/ios/ios_config.dart';
import 'package:patrol_gen/src/generators/output_file.dart';
import 'package:patrol_gen/src/schema.dart';

class IOSURLSessionClientGenerator {
  OutputFile generate(Service service, IOSConfig config) {
    final buffer = StringBuffer()..write(_contentPrefix(config));

    buffer.write(_createClass(service));

    return OutputFile(
      filename: config.clientFileName(service.name),
      content: buffer.toString(),
    );
  }

  String _contentPrefix(IOSConfig config) {
    return '''
///
//  swift-format-ignore-file
//
//  Generated code. Do not modify.
//  source: schema.dart
//

''';
  }

  String _createClass(Service service) {
    final endpoints = service.endpoints.map(_createEndpoint).join('\n\n');

    final url = r'http://\(address):\(port)/\(requestName)';

    final throwException =
        r'throw PatrolError.internal("Invalid response: \(response) \(data)")';

    return '''
class ${service.name}Client {
  private let port: Int
  private let address: String
  private let timeout: TimeInterval

  init(port: Int, address: String, timeout: TimeInterval) {
    self.port = port
    self.address = address
    self.timeout = timeout
  }

$endpoints

  private func performRequest<TResult: Codable>(requestName: String, body: Data? = nil) async throws -> TResult {
    let url = URL(string: "$url")!

    let urlconfig = URLSessionConfiguration.default
    urlconfig.timeoutIntervalForRequest = timeout
    urlconfig.timeoutIntervalForResource = timeout

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = body
    request.timeoutInterval = timeout

    let (data, response) = try await URLSession(configuration: urlconfig).data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
        $throwException
    }

    return try JSONDecoder().decode(TResult.self, from: data)
  }
}
''';
  }

  String _createEndpoint(Endpoint endpoint) {
    final parameterDef =
        endpoint.request != null ? 'request: ${endpoint.request!.name}' : '';
    final returnDef =
        endpoint.response != null ? '-> ${endpoint.response!.name}' : '';

    final bodyCode = endpoint.request != null
        ? '\n    let body = try JSONEncoder().encode(request)'
        : '';

    final bodyArgument = bodyCode.isNotEmpty ? ', body: body' : '';

    return '''
  func ${endpoint.name}($parameterDef) async throws $returnDef {$bodyCode
    return try await performRequest(requestName: "${endpoint.name}"${bodyArgument})
  }''';
  }
}
