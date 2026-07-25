import 'package:hive/hive.dart';

Future<void> saveToken(String token) async {
  var box = await Hive.openBox("authBox");
  await box.put("jwt", token);
  await box.close();
}

Future<void> saveRefreshToken(String token) async {
  var box = await Hive.openBox("authBox");
  await box.put("refreshToken", token);
  await box.close();
}

Future<String?> getRefreshToken() async {
  var box = await Hive.openBox("authBox");
  final token = box.get("refreshToken");
  await box.close();
  return token;
}


Future<void> saveUser(Map<String, dynamic> user) async {
  var box = await Hive.openBox("authBox");
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
  await box.close();
}

Future<String?> getToken() async {
  var box = await Hive.openBox("authBox");
  final token = await box.get("jwt");
  await box.close();
  return token;
}

Future<Map<String, dynamic>> getUser() async {
  var box = await Hive.openBox("authBox");
  final user = <String, dynamic>{
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
  await box.close();
  return user;
}


Future<void> logout() async {
  var box = await Hive.openBox("authBox");
  await box.clear();
  await box.close();
}
