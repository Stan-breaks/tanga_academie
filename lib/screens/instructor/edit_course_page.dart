import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/storage_service.dart';
import 'package:tanga_acadamie/core/theme/app_colors.dart';

class EditCoursePage extends StatefulWidget {
  final Map<String, dynamic> course;
  
  const EditCoursePage({super.key, required this.course});

  @override
  State<EditCoursePage> createState() => _EditCoursePageState();
}

class _EditCoursePageState extends State<EditCoursePage> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentStep = 0;

  // Form Controllers
  late TextEditingController _titleController;
  late TextEditingController _priceController;
  late TextEditingController _discountedPriceController;
  late TextEditingController _descriptionController;
  late TextEditingController _requirementsController;
  late TextEditingController _benefitsController;
  late TextEditingController _tagsController;

  // Dropdown/Selection values
  String _selectedCategory = 'All';
  String _selectedOfferType = 'premium';
  String _selectedLanguage = 'French';
  DateTime? _startDate;

  // Category options
  final List<String> _categories = [
    'All',
    'Programming',
    'Design',
    'Business',
    'Marketing',
    'Photography',
    'Music',
    'Health',
    'Language',
    'Other',
  ];

  // Offer type options
  final List<String> _offerTypes = ['freemium', 'premium', 'free'];

  // Language options
  final List<String> _languages = [
    'French',
    'English',
    'Swahili',
    'Arabic',
    'Spanish',
    'Portuguese',
  ];

  // Files
  File? _bannerImage;
  String? _existingBannerUrl;
  File? _certificateFile;
  String? _existingCertificateUrl;
  final List<File> _newPdfFiles = [];
  List<Map<String, dynamic>> _existingPdfFiles = [];

  // Chapters and Lessons
  final List<EditChapterData> _chapters = [];

  bool _isLoading = false;
  String? _errorMessage;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initializeFromCourse();
  }

  void _initializeFromCourse() {
    final course = widget.course;
    
    // Initialize text controllers
    _titleController = TextEditingController(text: course['title'] ?? '');
    _priceController = TextEditingController(text: course['price']?.toString() ?? '');
    _discountedPriceController = TextEditingController(
      text: course['discountedPrice']?.toString() ?? '',
    );
    _descriptionController = TextEditingController(text: course['description'] ?? '');
    _requirementsController = TextEditingController(text: course['requirements'] ?? '');
    _benefitsController = TextEditingController(text: course['benefits'] ?? '');
    
    // Initialize tags
    final tags = course['tags'] as List<dynamic>? ?? [];
    _tagsController = TextEditingController(text: tags.join(', '));

    // Initialize dropdown values
    _selectedCategory = course['category'] ?? 'All';
    if (!_categories.contains(_selectedCategory)) {
      _selectedCategory = 'All';
    }
    
    _selectedOfferType = course['offerType'] ?? 'premium';
    if (!_offerTypes.contains(_selectedOfferType)) {
      _selectedOfferType = 'premium';
    }
    
    _selectedLanguage = course['language'] ?? 'French';
    if (!_languages.contains(_selectedLanguage)) {
      _selectedLanguage = 'French';
    }

    // Initialize start date
    if (course['startDate'] != null) {
      try {
        _startDate = DateTime.parse(course['startDate']);
      } catch (_) {
        _startDate = null;
      }
    }
    
    // Initialize existing files
    _existingBannerUrl = course['bannerImage'];
    _existingCertificateUrl = course['certificateFile'];
    _existingPdfFiles = (course['pdfFiles'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    
    // Initialize chapters and lessons
    final chapters = course['chapters'] as List<dynamic>? ?? [];
    for (var chapter in chapters) {
      final chapterData = EditChapterData(
        titleController: TextEditingController(text: chapter['title'] ?? ''),
        order: chapter['order'] ?? _chapters.length + 1,
        isLockedUntilQuizPass: chapter['isLockedUntilQuizPass'] ?? false,
        lessons: [],
      );
      
      final lessons = chapter['lessons'] as List<dynamic>? ?? [];
      for (var lesson in lessons) {
        final video = lesson['video'] as Map<String, dynamic>?;
        chapterData.lessons.add(EditLessonData(
          titleController: TextEditingController(text: lesson['title'] ?? ''),
          order: lesson['order'] ?? chapterData.lessons.length + 1,
          existingVideoUrl: video?['url'],
          videoDuration: video?['duration'] ?? 0,
          videoTitle: video?['title'],
        ));
      }
      
      _chapters.add(chapterData);
    }
    
    // Add at least one empty chapter if none exist
    if (_chapters.isEmpty) {
      _addChapter();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _discountedPriceController.dispose();
    _descriptionController.dispose();
    _requirementsController.dispose();
    _benefitsController.dispose();
    _tagsController.dispose();
    _pageController.dispose();
    for (var chapter in _chapters) {
      chapter.dispose();
    }
    super.dispose();
  }

  void _addChapter() {
    setState(() {
      _chapters.add(EditChapterData(
        titleController: TextEditingController(),
        order: _chapters.length + 1,
        isLockedUntilQuizPass: false,
        lessons: [EditLessonData(titleController: TextEditingController(), order: 1)],
      ));
    });
  }

  void _removeChapter(int index) {
    if (_chapters.length > 1) {
      setState(() {
        _chapters[index].dispose();
        _chapters.removeAt(index);
        for (int i = 0; i < _chapters.length; i++) {
          _chapters[i].order = i + 1;
        }
      });
    }
  }

  void _addLesson(int chapterIndex) {
    setState(() {
      _chapters[chapterIndex].lessons.add(EditLessonData(
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
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() {
        _certificateFile = File(file.path);
      });
    }
  }

  Future<void> _pickPdfFiles() async {
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() {
        _newPdfFiles.add(File(file.path));
      });
    }
  }

  Future<void> _pickLessonVideo(int chapterIndex, int lessonIndex) async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _chapters[chapterIndex].lessons[lessonIndex].newVideoFile = File(video.path);
      });
    }
  }

  Future<void> _updateCourse() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate chapters
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
      final courseId = widget.course['_id'];

      final formData = FormData();

      // Add basic fields
      formData.fields.addAll([
        MapEntry('title', _titleController.text),
        MapEntry('slug', widget.course['slug'] ?? ''), // Keep existing slug
        MapEntry('price', _priceController.text),
        MapEntry('category', _selectedCategory),
        MapEntry('offerType', _selectedOfferType),
        MapEntry('language', _selectedLanguage),
        MapEntry('description', _descriptionController.text),
        MapEntry('tags', _tagsController.text),
      ]);

      // Add optional fields if provided
      if (_discountedPriceController.text.isNotEmpty) {
        formData.fields.add(MapEntry('discountedPrice', _discountedPriceController.text));
      }
      if (_requirementsController.text.isNotEmpty) {
        formData.fields.add(MapEntry('requirements', _requirementsController.text));
      }
      if (_benefitsController.text.isNotEmpty) {
        formData.fields.add(MapEntry('benefits', _benefitsController.text));
      }
      if (_startDate != null) {
        formData.fields.add(MapEntry('startDate', _startDate!.toIso8601String()));
      }

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
            MapEntry('chapters[$i][lessons][$j][video][title]', lesson.videoTitle ?? lesson.titleController.text),
          ]);
          
          // If there's an existing video URL and no new video, include it
          if (lesson.existingVideoUrl != null && lesson.newVideoFile == null) {
            formData.fields.add(
              MapEntry('chapters[$i][lessons][$j][video][url]', lesson.existingVideoUrl!),
            );
          }
        }
      }

      // Add banner image if changed
      if (_bannerImage != null) {
        formData.files.add(MapEntry(
          'bannerImage',
          await MultipartFile.fromFile(_bannerImage!.path),
        ));
      }

      // Add certificate file if changed
      if (_certificateFile != null) {
        formData.files.add(MapEntry(
          'certificateFile',
          await MultipartFile.fromFile(_certificateFile!.path),
        ));
      }

      // Add new PDF files
      for (var pdf in _newPdfFiles) {
        formData.files.add(MapEntry(
          'pdfFiles',
          await MultipartFile.fromFile(pdf.path),
        ));
      }

      // Add new lesson videos
      for (var chapter in _chapters) {
        for (var lesson in chapter.lessons) {
          if (lesson.newVideoFile != null) {
            formData.files.add(MapEntry(
              'lessonVideo',
              await MultipartFile.fromFile(lesson.newVideoFile!.path),
            ));
          }
        }
      }

      final response = await dio.put(
        '${ApiConfig.baseUrl}/api/courses/$courseId',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Course updated successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context, true); // Return true to indicate update
        }
      } else {
        setState(() {
          _errorMessage = response.data['message'] ?? 'Failed to update course';
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
          'Edit Course',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textDark,
        actions: [
          // Course status badge
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: Center(
              child: _buildStatusBadge(widget.course['status'] ?? 'draft'),
            ),
          ),
        ],
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
                    const Icon(Icons.error_outline, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.error),
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

  Widget _buildStatusBadge(String status) {
    final statusColors = {
      'published': AppColors.success,
      'pending': AppColors.warning,
      'draft': AppColors.textLight,
      'rejected': AppColors.error,
    };
    final color = statusColors[status] ?? AppColors.textLight;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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
          _buildSectionHeader('Course Details', Icons.edit_note),
          const SizedBox(height: 16),
          
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

          // Category Dropdown
          _buildDropdownField(
            label: 'Category',
            value: _selectedCategory,
            items: _categories,
            icon: Icons.category,
            onChanged: (value) {
              setState(() {
                _selectedCategory = value!;
              });
            },
          ),
          const SizedBox(height: 16),

          // Offer Type Dropdown
          _buildDropdownField(
            label: 'Offer Type',
            value: _selectedOfferType,
            items: _offerTypes,
            icon: Icons.local_offer,
            onChanged: (value) {
              setState(() {
                _selectedOfferType = value!;
              });
            },
          ),
          const SizedBox(height: 16),

          // Price Fields Row
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  controller: _priceController,
                  label: 'Price',
                  hint: 'Course price',
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
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInputField(
                  controller: _discountedPriceController,
                  label: 'Discounted Price',
                  hint: 'Optional',
                  icon: Icons.discount,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      if (double.tryParse(value) == null) {
                        return 'Enter a valid price';
                      }
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Language Dropdown
          _buildDropdownField(
            label: 'Language',
            value: _selectedLanguage,
            items: _languages,
            icon: Icons.language,
            onChanged: (value) {
              setState(() {
                _selectedLanguage = value!;
              });
            },
          ),
          const SizedBox(height: 16),

          // Start Date Picker
          _buildDatePickerField(
            label: 'Start Date',
            value: _startDate,
            icon: Icons.calendar_today,
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _startDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: AppColors.primary,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (date != null) {
                setState(() {
                  _startDate = date;
                });
              }
            },
          ),
          const SizedBox(height: 16),

          _buildInputField(
            controller: _descriptionController,
            label: 'Description',
            hint: 'Describe your course in detail (max 5000 characters)',
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

          // Requirements Field
          _buildInputField(
            controller: _requirementsController,
            label: 'Requirements',
            hint: 'What should students know before taking this course?',
            icon: Icons.checklist,
            maxLines: 3,
          ),
          const SizedBox(height: 16),

          // Benefits Field
          _buildInputField(
            controller: _benefitsController,
            label: 'What Students Will Learn',
            hint: 'List the key benefits and learning outcomes',
            icon: Icons.emoji_events,
            maxLines: 3,
          ),
          const SizedBox(height: 16),

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
            'Edit chapters and lessons',
            style: TextStyle(
              color: AppColors.textLight,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _chapters.length,
            itemBuilder: (context, chapterIndex) {
              return _buildChapterCard(chapterIndex);
            },
          ),

          const SizedBox(height: 16),

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
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: () => _removeChapter(chapterIndex),
                )
              : null,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildInputField(
                    controller: chapter.titleController,
                    label: 'Chapter Title',
                    hint: 'Enter chapter title',
                    icon: Icons.bookmark,
                    onChanged: (value) => setState(() {}),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
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

                  const Row(
                    children: [
                      Icon(Icons.play_lesson, color: AppColors.textDark, size: 20),
                      SizedBox(width: 8),
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

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: chapter.lessons.length,
                    itemBuilder: (context, lessonIndex) {
                      return _buildLessonCard(chapterIndex, lessonIndex);
                    },
                  ),

                  const SizedBox(height: 12),

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
    final hasVideo = lesson.newVideoFile != null || lesson.existingVideoUrl != null;
    
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
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              if (hasVideo) ...[
                const SizedBox(width: 8),
                const Icon(Icons.videocam, size: 16, color: AppColors.success),
              ],
              const Spacer(),
              if (_chapters[chapterIndex].lessons.length > 1)
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.error, size: 20),
                  onPressed: () => _removeLesson(chapterIndex, lessonIndex),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 12),

          _buildInputField(
            controller: lesson.titleController,
            label: 'Lesson Title',
            hint: 'Enter lesson title',
            icon: Icons.edit,
          ),
          const SizedBox(height: 12),

          // Show existing video info if available
          if (lesson.existingVideoUrl != null && lesson.newVideoFile == null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.video_file, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Existing Video',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          'Duration: ${lesson.videoDuration}s',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          _buildFilePickerButton(
            label: lesson.newVideoFile != null
                ? 'New Video Selected ✓'
                : lesson.existingVideoUrl != null
                    ? 'Replace Video'
                    : 'Upload Lesson Video',
            icon: Icons.video_library,
            onPressed: () => _pickLessonVideo(chapterIndex, lessonIndex),
            isSelected: lesson.newVideoFile != null,
          ),

          if (lesson.newVideoFile != null || lesson.existingVideoUrl != null) ...[
            const SizedBox(height: 12),
            // Show new video file preview
            if (lesson.newVideoFile != null)
              _buildVideoPreview(lesson.newVideoFile!),
            if (lesson.newVideoFile != null)
              const SizedBox(height: 12),
            _buildInputField(
              label: 'Video Duration (seconds)',
              hint: 'Enter video duration',
              icon: Icons.timer,
              keyboardType: TextInputType.number,
              initialValue: lesson.videoDuration.toString(),
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

          // Banner Image
          _buildFileSectionCard(
            title: 'Banner Image',
            description: 'The main image for your course',
            icon: Icons.image,
            child: Column(
              children: [
                // Show existing or new banner
                if (_bannerImage != null || _existingBannerUrl != null)
                  Container(
                    height: 150,
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: _bannerImage != null
                            ? FileImage(_bannerImage!)
                            : NetworkImage(ApiConfig.getImageUrl(_existingBannerUrl)) as ImageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                _buildFilePickerButton(
                  label: _bannerImage != null
                      ? 'New Image Selected ✓'
                      : _existingBannerUrl != null
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

          // Certificate File
          _buildFileSectionCard(
            title: 'Certificate Template',
            description: 'Upload a certificate template for course completion',
            icon: Icons.workspace_premium,
            child: Column(
              children: [
                if (_existingCertificateUrl != null && _certificateFile == null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.verified, color: AppColors.success),
                        SizedBox(width: 8),
                        Text(
                          'Certificate template exists',
                          style: TextStyle(color: AppColors.success),
                        ),
                      ],
                    ),
                  ),
                _buildFilePickerButton(
                  label: _certificateFile != null
                      ? 'New Certificate Selected ✓'
                      : _existingCertificateUrl != null
                          ? 'Replace Certificate'
                          : 'Upload Certificate',
                  icon: Icons.upload_file,
                  onPressed: _pickCertificateFile,
                  isSelected: _certificateFile != null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // PDF Files
          _buildFileSectionCard(
            title: 'Course Materials (PDFs)',
            description: 'Add supplementary PDF materials',
            icon: Icons.picture_as_pdf,
            child: Column(
              children: [
                // Existing PDFs
                if (_existingPdfFiles.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Existing Files',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._existingPdfFiles.map((pdf) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.insert_drive_file, 
                                color: AppColors.error, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  pdf['title'] ?? 'PDF File',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                
                // New PDFs
                if (_newPdfFiles.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'New Files',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._newPdfFiles.asMap().entries.map((entry) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.insert_drive_file, 
                                color: AppColors.primary, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  entry.value.path.split('/').last,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, 
                                  color: AppColors.textLight, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _newPdfFiles.removeAt(entry.key);
                                  });
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        )),
                      ],
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
          _buildSectionHeader('Review Changes', Icons.preview),
          const SizedBox(height: 16),

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
                _buildReviewItem('Price', ' ${_priceController.text}'),
                _buildReviewItem('Chapters', '${_chapters.length}'),
                _buildReviewItem(
                  'Total Lessons', 
                  '${_chapters.fold(0, (sum, c) => sum + c.lessons.length)}',
                ),
                _buildReviewItem(
                  'Banner Image', 
                  _bannerImage != null 
                      ? '✓ New image selected' 
                      : _existingBannerUrl != null 
                          ? '✓ Using existing' 
                          : '✗ Not set',
                ),
                _buildReviewItem(
                  'Certificate', 
                  _certificateFile != null 
                      ? '✓ New file selected' 
                      : _existingCertificateUrl != null 
                          ? '✓ Using existing' 
                          : '✗ Not set',
                ),
                _buildReviewItem(
                  'PDF Materials', 
                  '${_existingPdfFiles.length} existing, ${_newPdfFiles.length} new',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Course Structure',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),

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
                          style: const TextStyle(
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
                      final hasVideo = lesson.newVideoFile != null || lesson.existingVideoUrl != null;
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
                              hasVideo ? Icons.videocam : Icons.videocam_off,
                              size: 14,
                              color: hasVideo ? AppColors.success : AppColors.textLight,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              lesson.titleController.text.isEmpty
                                  ? 'Lesson ${lesson.order}'
                                  : lesson.titleController.text,
                              style: const TextStyle(
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
              style: const TextStyle(
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
                    onPressed: _isLoading ? null : _updateCourse,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isLoading ? 'Saving...' : 'Save Changes'),
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
    String? initialValue,
  }) {
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
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

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(
            item[0].toUpperCase() + item.substring(1),
            style: const TextStyle(fontSize: 16),
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required DateTime? value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              value != null
                  ? '${value.day}/${value.month}/${value.year}'
                  : 'Select a date',
              style: TextStyle(
                fontSize: 16,
                color: value != null ? AppColors.textDark : AppColors.textLight,
              ),
            ),
            Icon(Icons.arrow_drop_down, color: AppColors.textLight),
          ],
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
                      style: const TextStyle(
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

  Widget _buildVideoPreview(File videoFile) {
    final fileName = videoFile.path.split('/').last;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.video_file,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'New Video Selected',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  fileName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.check_circle,
            color: AppColors.success,
            size: 20,
          ),
        ],
      ),
    );
  }
}

// Data classes for editing
class EditChapterData {
  TextEditingController titleController;
  int order;
  bool isLockedUntilQuizPass;
  List<EditLessonData> lessons;

  EditChapterData({
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

class EditLessonData {
  TextEditingController titleController;
  int order;
  String? existingVideoUrl;
  File? newVideoFile;
  int videoDuration;
  String? videoTitle;

  EditLessonData({
    required this.titleController,
    required this.order,
    this.existingVideoUrl,
    this.newVideoFile,
    this.videoDuration = 0,
    this.videoTitle,
  });

  void dispose() {
    titleController.dispose();
  }
}
