import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/storage_service.dart';
import 'package:tanga_acadamie/core/theme/app_colors.dart';

class CreateCoursePage extends StatefulWidget {
  const CreateCoursePage({super.key});

  @override
  State<CreateCoursePage> createState() => _CreateCoursePageState();
}

class _CreateCoursePageState extends State<CreateCoursePage> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentStep = 0;

  // Form Controllers
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();

  // Files
  File? _bannerImage;
  File? _certificateFile;
  final List<File> _pdfFiles = [];

  // Chapters and Lessons
  final List<ChapterData> _chapters = [];

  bool _isLoading = false;
  String? _errorMessage;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Add a default chapter
    _addChapter();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _addChapter() {
    setState(() {
      _chapters.add(ChapterData(
        titleController: TextEditingController(),
        order: _chapters.length + 1,
        isLockedUntilQuizPass: false,
        lessons: [LessonData(titleController: TextEditingController(), order: 1)],
      ));
    });
  }

  void _removeChapter(int index) {
    if (_chapters.length > 1) {
      setState(() {
        _chapters[index].dispose();
        _chapters.removeAt(index);
        // Update order numbers
        for (int i = 0; i < _chapters.length; i++) {
          _chapters[i].order = i + 1;
        }
      });
    }
  }

  void _addLesson(int chapterIndex) {
    setState(() {
      _chapters[chapterIndex].lessons.add(LessonData(
        titleController: TextEditingController(),
        order: _chapters[chapterIndex].lessons.length + 1,
      ));
    });
  }

  void _removeLesson(int chapterIndex, int lessonIndex) {
    if (_chapters[chapterIndex].lessons.length > 1) {
      setState(() {
        _chapters[chapterIndex].lessons[lessonIndex].dispose();
        _chapters[chapterIndex].lessons.removeAt(lessonIndex);
        // Update order numbers
        for (int i = 0; i < _chapters[chapterIndex].lessons.length; i++) {
          _chapters[chapterIndex].lessons[i].order = i + 1;
        }
      });
    }
  }

  Future<void> _pickBannerImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _bannerImage = File(image.path);
      });
    }
  }

  Future<void> _pickCertificateFile() async {
    // For now, use image picker - in production, use file_picker package
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() {
        _certificateFile = File(file.path);
      });
    }
  }

  Future<void> _pickPdfFiles() async {
    // For now, use image picker - in production, use file_picker package
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() {
        _pdfFiles.add(File(file.path));
      });
    }
  }

  Future<void> _pickLessonVideo(int chapterIndex, int lessonIndex) async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _chapters[chapterIndex].lessons[lessonIndex].videoFile = File(video.path);
      });
    }
  }


  Future<void> _submitCourse() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate at least one chapter with lessons
    if (_chapters.isEmpty) {
      setState(() {
        _errorMessage = 'At least one chapter with lessons is required';
      });
      return;
    }

    for (var chapter in _chapters) {
      if (chapter.titleController.text.isEmpty) {
        setState(() {
          _errorMessage = 'All chapters must have a title';
        });
        return;
      }
      if (chapter.lessons.isEmpty) {
        setState(() {
          _errorMessage = 'Each chapter must have at least one lesson';
        });
        return;
      }
      for (var lesson in chapter.lessons) {
        if (lesson.titleController.text.isEmpty) {
          setState(() {
            _errorMessage = 'All lessons must have a title';
          });
          return;
        }
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await getToken();
      final dio = Dio();

      final formData = FormData();

      // Add basic fields
      formData.fields.addAll([
        MapEntry('title', _titleController.text),
        MapEntry('price', _priceController.text),
        MapEntry('description', _descriptionController.text),
        MapEntry('tags', _tagsController.text),
      ]);

      // Add chapters data
      for (int i = 0; i < _chapters.length; i++) {
        final chapter = _chapters[i];
        formData.fields.addAll([
          MapEntry('chapters[$i][title]', chapter.titleController.text),
          MapEntry('chapters[$i][order]', chapter.order.toString()),
          MapEntry('chapters[$i][isLockedUntilQuizPass]', chapter.isLockedUntilQuizPass.toString()),
        ]);

        for (int j = 0; j < chapter.lessons.length; j++) {
          final lesson = chapter.lessons[j];
          formData.fields.addAll([
            MapEntry('chapters[$i][lessons][$j][title]', lesson.titleController.text),
            MapEntry('chapters[$i][lessons][$j][order]', lesson.order.toString()),
            MapEntry('chapters[$i][lessons][$j][video][duration]', lesson.videoDuration.toString()),
            MapEntry('chapters[$i][lessons][$j][video][title]', lesson.titleController.text),
          ]);
        }
      }

      // Add banner image
      if (_bannerImage != null) {
        formData.files.add(MapEntry(
          'bannerImage',
          await MultipartFile.fromFile(_bannerImage!.path),
        ));
      }

      // Add certificate file
      if (_certificateFile != null) {
        formData.files.add(MapEntry(
          'certificateFile',
          await MultipartFile.fromFile(_certificateFile!.path),
        ));
      }

      // Add PDF files
      for (var pdf in _pdfFiles) {
        formData.files.add(MapEntry(
          'pdfFiles',
          await MultipartFile.fromFile(pdf.path),
        ));
      }

      // Add lesson videos
      for (var chapter in _chapters) {
        for (var lesson in chapter.lessons) {
          if (lesson.videoFile != null) {
            formData.files.add(MapEntry(
              'lessonVideo',
              await MultipartFile.fromFile(lesson.videoFile!.path),
            ));
          }
        }
      }

      final response = await dio.post(
        '${ApiConfig.baseUrl}/api/create-course',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Course created successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        setState(() {
          _errorMessage = response.data['message'] ?? 'Failed to create course';
        });
      }
    } catch (e) {
      setState(() {
        if (e is DioException) {
          _errorMessage = e.response?.data['message'] ?? e.message ?? 'An error occurred';
        } else {
          _errorMessage = e.toString();
        }
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _nextStep() {
    if (_currentStep < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep++;
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Course',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textDark,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildStepIndicator(),
            
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() {
                    _currentStep = index;
                  });
                },
                children: [
                  _buildBasicInfoStep(),
                  _buildChaptersStep(),
                  _buildFilesStep(),
                  _buildReviewStep(),
                ],
              ),
            ),

            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['Basic Info', 'Chapters', 'Files', 'Review'];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        children: List.generate(steps.length, (index) {
          final isActive = index <= _currentStep;
          final isCompleted = index < _currentStep;
          
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: isActive
                              ? const LinearGradient(
                                  colors: [
                                    AppColors.primaryLight,
                                    AppColors.primary,
                                  ],
                                )
                              : null,
                          color: isActive ? null : Colors.grey.shade300,
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: isCompleted
                              ? const Icon(Icons.check, color: Colors.white, size: 20)
                              : Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: isActive ? Colors.white : Colors.grey.shade600,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        steps[index],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          color: isActive ? AppColors.primary : AppColors.textLight,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                if (index < steps.length - 1)
                  Container(
                    height: 2,
                    width: 24,
                    margin: const EdgeInsets.only(bottom: 24),
                    color: index < _currentStep
                        ? AppColors.primary
                        : Colors.grey.shade300,
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBasicInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Course Details', Icons.info_outline),
          const SizedBox(height: 16),
          
          // Title Field
          _buildInputField(
            controller: _titleController,
            label: 'Course Title',
            hint: 'Enter a descriptive course title',
            icon: Icons.title,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Title is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Price Field
          _buildInputField(
            controller: _priceController,
            label: 'Price',
            hint: 'Enter course price',
            icon: Icons.attach_money,
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Price is required';
              }
              if (double.tryParse(value) == null) {
                return 'Enter a valid price';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Description Field
          _buildInputField(
            controller: _descriptionController,
            label: 'Description',
            hint: 'Describe your course in detail',
            icon: Icons.description,
            maxLines: 5,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Description is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Tags Field
          _buildInputField(
            controller: _tagsController,
            label: 'Tags (comma-separated)',
            hint: 'e.g., programming, web development, flutter',
            icon: Icons.tag,
          ),
        ],
      ),
    );
  }

  Widget _buildChaptersStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Course Structure', Icons.menu_book),
          const SizedBox(height: 8),
          Text(
            'Organize your course into chapters and lessons',
            style: TextStyle(
              color: AppColors.textLight,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),

          // Chapters List
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _chapters.length,
            itemBuilder: (context, chapterIndex) {
              return _buildChapterCard(chapterIndex);
            },
          ),

          const SizedBox(height: 16),

          // Add Chapter Button
          _buildAddButton(
            onPressed: _addChapter,
            label: 'Add Chapter',
            icon: Icons.add_box,
          ),
        ],
      ),
    );
  }

  Widget _buildChapterCard(int chapterIndex) {
    final chapter = _chapters[chapterIndex];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            AppColors.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryLight, AppColors.primary],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${chapter.order}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  chapter.titleController.text.isEmpty
                      ? 'Chapter ${chapter.order}'
                      : chapter.titleController.text,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          trailing: _chapters.length > 1
              ? IconButton(
                  icon: Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: () => _removeChapter(chapterIndex),
                )
              : null,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Chapter Title Input
                  _buildInputField(
                    controller: chapter.titleController,
                    label: 'Chapter Title',
                    hint: 'Enter chapter title',
                    icon: Icons.bookmark,
                    onChanged: (value) => setState(() {}),
                  ),
                  const SizedBox(height: 12),

                  // Lock until quiz pass toggle
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Lock until quiz pass',
                            style: TextStyle(
                              color: AppColors.textDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Switch(
                          value: chapter.isLockedUntilQuizPass,
                          onChanged: (value) {
                            setState(() {
                              chapter.isLockedUntilQuizPass = value;
                            });
                          },
                          activeTrackColor: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Lessons Header
                  Row(
                    children: [
                      Icon(Icons.play_lesson, color: AppColors.textDark, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Lessons',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Lessons List
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: chapter.lessons.length,
                    itemBuilder: (context, lessonIndex) {
                      return _buildLessonCard(chapterIndex, lessonIndex);
                    },
                  ),

                  const SizedBox(height: 12),

                  // Add Lesson Button
                  _buildAddButton(
                    onPressed: () => _addLesson(chapterIndex),
                    label: 'Add Lesson',
                    icon: Icons.add_circle_outline,
                    compact: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonCard(int chapterIndex, int lessonIndex) {
    final lesson = _chapters[chapterIndex].lessons[lessonIndex];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Lesson ${lesson.order}',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              if (lesson.videoFile != null) ...[
                const SizedBox(width: 8),
                Icon(Icons.videocam, size: 16, color: AppColors.success),
              ],
              const Spacer(),
              if (_chapters[chapterIndex].lessons.length > 1)
                IconButton(
                  icon: Icon(Icons.close, color: AppColors.error, size: 20),
                  onPressed: () => _removeLesson(chapterIndex, lessonIndex),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Lesson Title
          _buildInputField(
            controller: lesson.titleController,
            label: 'Lesson Title',
            hint: 'Enter lesson title',
            icon: Icons.edit,
          ),
          const SizedBox(height: 12),

          // Video Upload
          _buildFilePickerButton(
            label: lesson.videoFile != null
                ? 'Video Selected ✓'
                : 'Upload Lesson Video',
            icon: Icons.video_library,
            onPressed: () => _pickLessonVideo(chapterIndex, lessonIndex),
            isSelected: lesson.videoFile != null,
          ),

          if (lesson.videoFile != null) ...[
            const SizedBox(height: 12),
            _buildInputField(
              label: 'Video Duration (seconds)',
              hint: 'Enter video duration',
              icon: Icons.timer,
              keyboardType: TextInputType.number,
              onChanged: (value) {
                lesson.videoDuration = int.tryParse(value) ?? 0;
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Course Files', Icons.folder_open),
          const SizedBox(height: 16),

          // Banner Image Section
          _buildFileSectionCard(
            title: 'Banner Image',
            description: 'The main image for your course',
            icon: Icons.image,
            child: Column(
              children: [
                if (_bannerImage != null)
                  Container(
                    height: 150,
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: FileImage(_bannerImage!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                _buildFilePickerButton(
                  label: _bannerImage != null
                      ? 'Change Image'
                      : 'Select Banner Image',
                  icon: Icons.upload,
                  onPressed: _pickBannerImage,
                  isSelected: _bannerImage != null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Certificate File Section
          _buildFileSectionCard(
            title: 'Certificate Template',
            description: 'Upload a certificate template for course completion',
            icon: Icons.workspace_premium,
            child: _buildFilePickerButton(
              label: _certificateFile != null
                  ? 'Certificate Selected ✓'
                  : 'Upload Certificate',
              icon: Icons.upload_file,
              onPressed: _pickCertificateFile,
              isSelected: _certificateFile != null,
            ),
          ),
          const SizedBox(height: 16),

          // PDF Files Section
          _buildFileSectionCard(
            title: 'Course Materials (PDFs)',
            description: 'Add supplementary PDF materials',
            icon: Icons.picture_as_pdf,
            child: Column(
              children: [
                if (_pdfFiles.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: _pdfFiles.asMap().entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(Icons.insert_drive_file, 
                                color: AppColors.error, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  entry.value.path.split('/').last,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close, 
                                  color: AppColors.textLight, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _pdfFiles.removeAt(entry.key);
                                  });
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                _buildFilePickerButton(
                  label: 'Add PDF File',
                  icon: Icons.add_circle_outline,
                  onPressed: _pickPdfFiles,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Review', Icons.preview),
          const SizedBox(height: 16),

          // Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.08),
                  AppColors.primaryLight.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReviewItem('Title', _titleController.text),
                _buildReviewItem('Price', 'TZS ${_priceController.text}'),
                _buildReviewItem('Chapters', '${_chapters.length}'),
                _buildReviewItem(
                  'Total Lessons', 
                  '${_chapters.fold(0, (sum, c) => sum + c.lessons.length)}',
                ),
                _buildReviewItem(
                  'Banner Image', 
                  _bannerImage != null ? '✓ Uploaded' : '✗ Not uploaded',
                ),
                _buildReviewItem(
                  'Certificate', 
                  _certificateFile != null ? '✓ Uploaded' : '✗ Not uploaded',
                ),
                _buildReviewItem(
                  'PDF Materials', 
                  '${_pdfFiles.length} files',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Chapters Summary
          Text(
            'Course Structure',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),

          // Course structure preview
          ...List.generate(_chapters.length, (index) {
            final chapter = _chapters[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8, 
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Ch. ${chapter.order}',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          chapter.titleController.text.isEmpty
                              ? 'Untitled Chapter'
                              : chapter.titleController.text,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: List.generate(chapter.lessons.length, (lessonIndex) {
                      final lesson = chapter.lessons[lessonIndex];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8, 
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              lesson.videoFile != null 
                                  ? Icons.videocam 
                                  : Icons.videocam_off,
                              size: 14,
                              color: lesson.videoFile != null 
                                  ? AppColors.success 
                                  : AppColors.textLight,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              lesson.titleController.text.isEmpty
                                  ? 'Lesson ${lesson.order}'
                                  : lesson.titleController.text,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildReviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _previousStep,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Previous'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.primary),
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            child: _currentStep < 3
                ? ElevatedButton.icon(
                    onPressed: _nextStep,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Next'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: _isLoading ? null : _submitCourse,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle),
                    label: Text(_isLoading ? 'Creating...' : 'Create Course'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryLight, AppColors.primary],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    TextEditingController? controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primary),
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16, 
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildAddButton({
    required VoidCallback onPressed,
    required String label,
    required IconData icon,
    bool compact = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: compact ? 18 : 20),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(
            vertical: compact ? 10 : 14,
          ),
          side: const BorderSide(
            color: AppColors.primary, 
            width: 1.5,
          ),
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildFilePickerButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool isSelected = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: isSelected ? AppColors.success : AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildFileSectionCard({
    required String title,
    required String description,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      description,
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// Data classes
class ChapterData {
  TextEditingController titleController;
  int order;
  bool isLockedUntilQuizPass;
  List<LessonData> lessons;

  ChapterData({
    required this.titleController,
    required this.order,
    required this.isLockedUntilQuizPass,
    required this.lessons,
  });

  void dispose() {
    titleController.dispose();
    for (var lesson in lessons) {
      lesson.dispose();
    }
  }
}

class LessonData {
  TextEditingController titleController;
  int order;
  File? videoFile;
  int videoDuration;

  LessonData({
    required this.titleController,
    required this.order,
    this.videoFile,
    this.videoDuration = 0,
  });

  void dispose() {
    titleController.dispose();
  }
}
