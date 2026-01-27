import 'package:flutter/material.dart';

/// Chapter data for course creation/editing
class ChapterData {
  TextEditingController titleController;
  bool isLockedUntilQuizPass;
  List<LessonData> lessons;

  ChapterData({
    TextEditingController? titleController,
    this.isLockedUntilQuizPass = false,
    List<LessonData>? lessons,
  })  : titleController = titleController ?? TextEditingController(),
        lessons = lessons ?? [];

  void dispose() {
    titleController.dispose();
    for (var lesson in lessons) {
      lesson.dispose();
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'title': titleController.text,
      'isLockedUntilQuizPass': isLockedUntilQuizPass,
      'lessons': lessons.map((l) => l.toJson()).toList(),
    };
  }
}

/// Lesson data for course creation/editing
class LessonData {
  TextEditingController titleController;
  TextEditingController contentController;
  String? videoPath;

  LessonData({
    TextEditingController? titleController,
    TextEditingController? contentController,
    this.videoPath,
  })  : titleController = titleController ?? TextEditingController(),
        contentController = contentController ?? TextEditingController();

  void dispose() {
    titleController.dispose();
    contentController.dispose();
  }

  Map<String, dynamic> toJson() {
    return {
      'title': titleController.text,
      'content': contentController.text,
      'videoPath': videoPath,
    };
  }

  factory LessonData.fromJson(Map<String, dynamic> json) {
    return LessonData(
      titleController: TextEditingController(text: json['title'] ?? ''),
      contentController: TextEditingController(text: json['content'] ?? ''),
      videoPath: json['video']?['url'],
    );
  }
}
