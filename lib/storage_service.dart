import 'package:hive/hive.dart';

Future<void> saveToken(String token) async {
  var box = await Hive.openBox("authBox");
  await box.put("jwt", token);
  await box.close();
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
    "userId": await box.get("userId"),
    "firstName": await box.get("firstName"),
    "lastName": await box.get("lastName"),
    "username": await box.get("username"),
    "email": await box.get("email"),
    "role": await box.get("role"),
    "isVerified": await box.get("isVerified"),
    "isActive": await box.get("isActive"),
    "profile": await box.get("profile"),
    "phoneNumber": await box.get("phoneNumber"),
    "skill": await box.get("skill"),
    "bio": await box.get("bio"),
  };
  await box.close();
  return user;
}


Future<void> logout() async {
  var box = await Hive.openBox("authBox");
  await box.delete("jwt");
  await box.delete("userId");
  await box.delete("role");
  await box.delete("email");
  await box.delete("firstName");
  await box.delete("lastName");
  await box.delete("username");
  await box.delete("isVerified");
  await box.delete("isActive");
  await box.delete("profile");
  await box.delete("phoneNumber");
  await box.delete("skill");
  await box.delete("bio");
  await box.close();
}
