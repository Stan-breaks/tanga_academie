import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/storage_service.dart';
import 'package:tanga_acadamie/core/theme/app_colors.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';

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
  final _discountedPriceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _requirementsController = TextEditingController();
  final _benefitsController = TextEditingController();
  final _tagsController = TextEditingController();

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
  File? _certificateFile;
  final List<File> _pdfFiles = [];

  // Chapters and Lessons
  final List<ChapterData> _chapters = [];

  bool _isLoading = false;
  String? _errorMessage;

  final ImagePicker _picker = ImagePicker();

  // Helper function to generate slug from title
  String _generateSlug(String title) {
    return title
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '') // Remove special chars
        .replaceAll(RegExp(r'\s+'), '-') // Replace spaces with hyphens
        .replaceAll(RegExp(r'-+'), '-'); // Remove multiple hyphens
  }

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
    _discountedPriceController.dispose();
    _descriptionController.dispose();
    _requirementsController.dispose();
    _benefitsController.dispose();
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
        _errorMessage = isFr ? 'Au moins un chapitre avec des leçons est requis' : 'At least one chapter with lessons is required';
      });
      return;
    }

    for (var chapter in _chapters) {
      if (chapter.titleController.text.isEmpty) {
        setState(() {
          _errorMessage = isFr ? 'Tous les chapitres doivent avoir un titre' : 'All chapters must have a title';
        });
        return;
      }
      if (chapter.lessons.isEmpty) {
        setState(() {
          _errorMessage = isFr ? 'Chaque chapitre doit avoir au moins une leçon' : 'Each chapter must have at least one lesson';
        });
        return;
      }
      for (var lesson in chapter.lessons) {
        if (lesson.titleController.text.isEmpty) {
          setState(() {
            _errorMessage = isFr ? 'Toutes les leçons doivent avoir un titre' : 'All lessons must have a title';
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

      // Generate slug from title
      final slug = _generateSlug(_titleController.text);

      // Add basic fields
      formData.fields.addAll([
        MapEntry('title', _titleController.text),
        MapEntry('slug', slug),
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
              content: Text(isFr ? 'Cours créé avec succès !' : 'Course created successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        setState(() {
          _errorMessage = response.data['message'] ?? (isFr ? 'Échec de la création du cours' : 'Failed to create course');
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
        title: Text(
          isFr ? 'Créer un cours' : 'Create Course',
          style: const TextStyle(fontWeight: FontWeight.bold),
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
    final steps = isFr ? ['Infos', 'Chapitres', 'Fichiers', 'Aperçu'] : ['Basic Info', 'Chapters', 'Files', 'Review'];
    
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
          _buildSectionHeader(isFr ? 'Détails du cours' : 'Course Details', Icons.info_outline),
          const SizedBox(height: 16),
          
          // Title Field
          _buildInputField(
            controller: _titleController,
            label: isFr ? 'Titre du cours' : 'Course Title',
            hint: isFr ? 'Entrez un titre descriptif' : 'Enter a descriptive course title',
            icon: Icons.title,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return isFr ? 'Le titre est requis' : 'Title is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Category Dropdown
          _buildDropdownField(
            label: isFr ? 'Catégorie' : 'Category',
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
            label: isFr ? 'Type d\'offre' : 'Offer Type',
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
                  label: isFr ? 'Prix' : 'Price',
                  hint: isFr ? 'Prix du cours' : 'Course price',
                  icon: Icons.attach_money,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return isFr ? 'Le prix est requis' : 'Price is required';
                    }
                    if (double.tryParse(value) == null) {
                      return isFr ? 'Entrez un prix valide' : 'Enter a valid price';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInputField(
                  controller: _discountedPriceController,
                  label: isFr ? 'Prix réduit' : 'Discounted Price',
                  hint: isFr ? 'Optionnel' : 'Optional',
                  icon: Icons.discount,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      if (double.tryParse(value) == null) {
                        return isFr ? 'Entrez un prix valide' : 'Enter a valid price';
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
            label: isFr ? 'Langue' : 'Language',
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
            label: isFr ? 'Date de début' : 'Start Date',
            value: _startDate,
            icon: Icons.calendar_today,
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _startDate ?? DateTime.now(),
                firstDate: DateTime.now(),
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

          // Description Field
          _buildInputField(
            controller: _descriptionController,
            label: isFr ? 'Description' : 'Description',
            hint: isFr ? 'Décrivez votre cours en détail (max 5000 caractères)' : 'Describe your course in detail (max 5000 characters)',
            icon: Icons.description,
            maxLines: 5,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return isFr ? 'La description est requise' : 'Description is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Requirements Field
          _buildInputField(
            controller: _requirementsController,
            label: isFr ? 'Prérequis' : 'Requirements',
            hint: isFr ? 'Que doivent savoir les étudiants avant de suivre ce cours ?' : 'What should students know before taking this course?',
            icon: Icons.checklist,
            maxLines: 3,
          ),
          const SizedBox(height: 16),

          // Benefits Field
          _buildInputField(
            controller: _benefitsController,
            label: isFr ? 'Ce que les étudiants apprendront' : 'What Students Will Learn',
            hint: isFr ? 'Listez les bénéfices et objectifs d\'apprentissage' : 'List the key benefits and learning outcomes',
            icon: Icons.emoji_events,
            maxLines: 3,
          ),
          const SizedBox(height: 16),

          // Tags Field
          _buildInputField(
            controller: _tagsController,
            label: isFr ? 'Étiquettes (séparées par des virgules)' : 'Tags (comma-separated)',
            hint: isFr ? 'ex: programmation, développement web, flutter' : 'e.g., programming, web development, flutter',
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
          _buildSectionHeader(isFr ? 'Structure du cours' : 'Course Structure', Icons.menu_book),
          const SizedBox(height: 8),
          Text(
            isFr ? 'Organisez votre cours en chapitres et leçons' : 'Organize your course into chapters and lessons',
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
            label: isFr ? 'Ajouter un chapitre' : 'Add Chapter',
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
                      ? '${isFr ? 'Chapitre' : 'Chapter'} ${chapter.order}'
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
                    label: isFr ? 'Titre du chapitre' : 'Chapter Title',
            hint: isFr ? 'Entrez le titre du chapitre' : 'Enter chapter title',
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
                            isFr ? 'Verrouiller jusqu\'au quiz réussi' : 'Lock until quiz pass',
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
                        isFr ? 'Leçons' : 'Lessons',
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
                    label: isFr ? 'Ajouter une leçon' : 'Add Lesson',
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
                  '${isFr ? 'Leçon' : 'Lesson'} ${lesson.order}',
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
            label: isFr ? 'Titre de la leçon' : 'Lesson Title',
            hint: isFr ? 'Entrez le titre de la leçon' : 'Enter lesson title',
            icon: Icons.edit,
          ),
          const SizedBox(height: 12),

          // Video Upload
          _buildFilePickerButton(
            label: lesson.videoFile != null
                ? (isFr ? 'Vidéo sélectionnée ✓' : 'Video Selected ✓')
                : (isFr ? 'Télécharger la vidéo' : 'Upload Lesson Video'),
            icon: Icons.video_library,
            onPressed: () => _pickLessonVideo(chapterIndex, lessonIndex),
            isSelected: lesson.videoFile != null,
          ),

          if (lesson.videoFile != null) ...[
            const SizedBox(height: 12),
            // Video Preview
            _buildVideoPreview(lesson.videoFile!),
            const SizedBox(height: 12),
            _buildInputField(
              label: isFr ? 'Durée de la vidéo (secondes)' : 'Video Duration (seconds)',
              hint: isFr ? 'Entrez la durée' : 'Enter video duration',
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
          _buildSectionHeader(isFr ? 'Fichiers du cours' : 'Course Files', Icons.folder_open),
          const SizedBox(height: 16),

          // Banner Image Section
          _buildFileSectionCard(
            title: isFr ? 'Image de bannière' : 'Banner Image',
            description: isFr ? 'L\'image principale de votre cours' : 'The main image for your course',
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
                      ? (isFr ? 'Changer l\'image' : 'Change Image')
                      : (isFr ? 'Sélectionner une image' : 'Select Banner Image'),
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
            title: isFr ? 'Modèle de certificat' : 'Certificate Template',
            description: isFr ? 'Téléchargez un modèle de certificat' : 'Upload a certificate template for course completion',
            icon: Icons.workspace_premium,
            child: _buildFilePickerButton(
              label: _certificateFile != null
                  ? (isFr ? 'Certificat sélectionné ✓' : 'Certificate Selected ✓')
                  : (isFr ? 'Télécharger le certificat' : 'Upload Certificate'),
              icon: Icons.upload_file,
              onPressed: _pickCertificateFile,
              isSelected: _certificateFile != null,
            ),
          ),
          const SizedBox(height: 16),

          // PDF Files Section
          _buildFileSectionCard(
            title: isFr ? 'Matériels de cours (PDFs)' : 'Course Materials (PDFs)',
            description: isFr ? 'Ajoutez des matériels PDF supplémentaires' : 'Add supplementary PDF materials',
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
                  label: isFr ? 'Ajouter un fichier PDF' : 'Add PDF File',
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
          _buildSectionHeader(isFr ? 'Aperçu' : 'Review', Icons.preview),
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
                _buildReviewItem(isFr ? 'Titre' : 'Title', _titleController.text),
                _buildReviewItem(isFr ? 'Prix' : 'Price', 'TZS ${_priceController.text}'),
                _buildReviewItem(isFr ? 'Chapitres' : 'Chapters', '${_chapters.length}'),
                _buildReviewItem(
                  isFr ? 'Total leçons' : 'Total Lessons', 
                  '${_chapters.fold(0, (sum, c) => sum + c.lessons.length)}',
                ),
                _buildReviewItem(
                  isFr ? 'Image de bannière' : 'Banner Image', 
                  _bannerImage != null ? (isFr ? '✓ Téléchargé' : '✓ Uploaded') : (isFr ? '✗ Non téléchargé' : '✗ Not uploaded'),
                ),
                _buildReviewItem(
                  isFr ? 'Certificat' : 'Certificate', 
                  _certificateFile != null ? (isFr ? '✓ Téléchargé' : '✓ Uploaded') : (isFr ? '✗ Non téléchargé' : '✗ Not uploaded'),
                ),
                _buildReviewItem(
                  isFr ? 'Matériels PDF' : 'PDF Materials', 
                  '${_pdfFiles.length} ${isFr ? 'fichiers' : 'files'}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Chapters Summary
          Text(
            isFr ? 'Structure du cours' : 'Course Structure',
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
                              ? (isFr ? 'Chapitre sans titre' : 'Untitled Chapter')
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
                                  ? '${isFr ? 'Leçon' : 'Lesson'} ${lesson.order}'
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
                label: Text(isFr ? 'Précédent' : 'Previous'),
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
                    label: Text(isFr ? 'Suivant' : 'Next'),
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
                    label: Text(isFr ? (_isLoading ? 'Création...' : 'Créer le cours') : (_isLoading ? 'Creating...' : 'Create Course')),
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
                  : (isFr ? 'Sélectionnez une date' : 'Select a date'),
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
                Text(
                  isFr ? 'Vidéo sélectionnée' : 'Video Selected',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  fileName,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            Icons.check_circle,
            color: AppColors.success,
            size: 20,
          ),
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
