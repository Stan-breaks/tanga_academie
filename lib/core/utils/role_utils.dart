import 'package:flutter/material.dart';

/// Returns the display colour associated with a user role string.
Color roleColor(String? role) {
  switch (role) {
    case 'admin':
      return Colors.deepPurple;
    case 'instructor':
      return Colors.teal;
    case 'student':
      return Colors.blueAccent;
    default:
      return Colors.grey;
  }
}
