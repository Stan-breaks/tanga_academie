import 'package:hive/hive.dart';

// The auth box is opened once and kept open for the app's lifetime. It used to
// be opened AND closed on every access, which added a disk round-trip to every
// getToken()/getUser() call (i.e. to virtually every API request).
const _authBoxName = "authBox";
Box? _authBox;

/// Pre-opens the auth box so the first read is instant. Safe to call more than
/// once; `Hive.openBox` returns the same instance if already open.
Future<void> initStorage() async {
  _authBox ??= await Hive.openBox(_authBoxName);
}

Future<Box> _box() async {
  return _authBox ??= await Hive.openBox(_authBoxName);
}

Future<void> saveToken(String token) async {
  final box = await _box();
  await box.put("jwt", token);
}

Future<void> saveRefreshToken(String token) async {
  final box = await _box();
  await box.put("refreshToken", token);
}

Future<String?> getRefreshToken() async {
  final box = await _box();
  return box.get("refreshToken");
}

Future<void> saveUser(Map<String, dynamic> user) async {
  final box = await _box();
  await box.put("userId", user['_id']);
  await box.put("firstName", user['firstName']);
  await box.put("lastName", user['lastName']);
  await box.put("username", user['username']);
  await box.put("email", user['email']);
  await box.put("isVerified", user['isVerified']);
  await box.put("isActive", user['isActive']);
  await box.put("role", user['role']);
  await box.put("profile", user['profile']);
  await box.put("phoneNumber", user['phoneNumber']);
  await box.put("skill", user['skill']);
  await box.put("bio", user['bio']);
}

Future<String?> getToken() async {
  final box = await _box();
  return box.get("jwt");
}

Future<Map<String, dynamic>> getUser() async {
  final box = await _box();
  return <String, dynamic>{
    "userId": box.get("userId"),
    "firstName": box.get("firstName"),
    "lastName": box.get("lastName"),
    "username": box.get("username"),
    "email": box.get("email"),
    "role": box.get("role"),
    "isVerified": box.get("isVerified"),
    "isActive": box.get("isActive"),
    "profile": box.get("profile"),
    "phoneNumber": box.get("phoneNumber"),
    "skill": box.get("skill"),
    "bio": box.get("bio"),
  };
}

Future<void> logout() async {
  final box = await _box();
  await box.clear();
}
