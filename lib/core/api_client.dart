import 'package:http/http.dart' as http;

/// A single shared HTTP client for the whole app.
///
/// The top-level `http.get()`/`http.post()` helpers create and close a client on
/// every call, which means a brand-new TCP + TLS handshake (hundreds of
/// milliseconds on mobile networks) for each request. Reusing one client keeps
/// the connection alive, so only the first request to the backend pays that cost.
final http.Client sharedHttpClient = http.Client();
