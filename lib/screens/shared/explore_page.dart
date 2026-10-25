import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tanga_acadamie/data_fetcher.dart';
import 'package:tanga_acadamie/screens/shared/course_card.dart';
import 'package:tanga_acadamie/screens/shared/course_details_page.dart';
import 'package:tanga_acadamie/screens/shared/blog_detail_page.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';
import 'package:tanga_acadamie/models/blog.dart';
import 'package:tanga_acadamie/services/blog_service.dart';
import 'package:tanga_acadamie/widgets/blog_card.dart';
import 'package:tanga_acadamie/core/utils/responsive.dart';
import 'package:tanga_acadamie/core/theme/app_colors.dart';
import 'package:tanga_acadamie/core/widgets/shimmer.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage>
    with SingleTickerProviderStateMixin {
  String selectedCategory = 'All';
  String searchQuery = '';
  List<String> categories = ['All'];
  final TextEditingController searchController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  late Future<Map<String, dynamic>> coursesFuture;
  late Future<List<Blog>> _blogsFuture;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    coursesFuture = _loadCourses();
    _blogsFuture = BlogService.fetchRecentBlogs();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
  }

  /// Loads the course list and starts the fade-in once the data arrives, so the
  /// animation is not started as a side effect inside build().
  Future<Map<String, dynamic>> _loadCourses() {
    final future = fetchCourses();
    future.then<void>(
      (_) {
        if (mounted && !_animationController.isCompleted) {
          _animationController.forward();
        }
      },
      onError: (_) {},
    );
    return future;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// Debounce search input so filtering (and rebuilds) don't run on every key
  /// stroke.
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        searchQuery = value;
      });
    });
  }

  Future<void> _refresh() async {
    final courses = _loadCourses();
    final blogs = BlogService.fetchRecentBlogs();
    if (!mounted) return;
    setState(() {
      coursesFuture = courses;
      _blogsFuture = blogs;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder(
        future: coursesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: CourseGridSkeleton(count: 6),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: const BoxDecoration(
                        color: AppColors.error50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.error_outline_rounded,
                        size: 40,
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isFr
                          ? 'Quelque chose a mal tourné'
                          : 'Something went wrong',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: const TextStyle(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(isFr ? 'Réessayer' : 'Try Again'),
                    ),
                  ],
                ),
              ),
            );
          } else {
            final courses = snapshot.data!['data'] as List;

            // Extract unique categories
            final uniqueCategories = courses
                .map((course) => course['category'] as String? ?? 'All')
                .toSet()
                .toList();
            categories = ['All', ...uniqueCategories.where((c) => c != 'All')];

            // Filter courses based on selected category AND search query
            final filteredCourses = courses.where((course) {
              final matchesCategory =
                  selectedCategory == 'All' ||
                  course['category'] == selectedCategory;

              final matchesSearch =
                  searchQuery.isEmpty ||
                  (course['title'] as String?)?.toLowerCase().contains(
                        searchQuery.toLowerCase(),
                      ) ==
                      true ||
                  (course['description'] as String?)?.toLowerCase().contains(
                        searchQuery.toLowerCase(),
                      ) ==
                      true;

              return matchesCategory && matchesSearch;
            }).toList();

            return FadeTransition(
              opacity: _fadeAnimation,
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _refresh,
                child: CustomScrollView(
                  slivers: [
                    // Header Section
                    SliverToBoxAdapter(
                      child: SizedBox(
                        width: double.infinity,
                        height: 200,
                        child: ClipRect(
                          child: Image.asset(
                            'public/banner1.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(child: _buildHeader()),

                    // Search Bar
                    SliverToBoxAdapter(child: _buildSearchBar()),

                    // Category Filter
                    SliverToBoxAdapter(child: _buildCategoryFilter()),

                    // Course Count
                    SliverToBoxAdapter(
                      child: _buildCourseCount(filteredCourses.length),
                    ),

                    // Courses Grid
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      sliver: filteredCourses.isEmpty
                          ? SliverToBoxAdapter(child: _buildEmptyState())
                          : SliverGrid(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: Responsive.gridColumns(context),
                                    childAspectRatio: 0.82,
                                    crossAxisSpacing: 14,
                                    mainAxisSpacing: 14,
                                  ),
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final course = filteredCourses[index];
                                return CourseCard(
                                  course: course,
                                  heroTag: course['_id'] != null
                                      ? 'course-banner-${course['_id']}'
                                      : null,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            CourseDetailsPage(course: course),
                                      ),
                                    );
                                  },
                                );
                              }, childCount: filteredCourses.length),
                            ),
                    ),
                    // Blog Section
                    SliverToBoxAdapter(child: _buildBlogSection()),
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary200,
                      AppColors.primary700,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.explore, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isFr ? 'Explorer les cours' : 'Explore Courses',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      isFr
                          ? 'Trouvez votre prochain cours'
                          : 'Find your next learning journey',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: searchController,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: isFr ? 'Rechercher des cours...' : 'Search courses...',
            hintStyle: TextStyle(color: AppColors.textLight),
            prefixIcon: Icon(Icons.search, color: AppColors.textLight),
            suffixIcon: searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: AppColors.textLight),
                    onPressed: () {
                      _searchDebounce?.cancel();
                      setState(() {
                        searchController.clear();
                        searchQuery = '';
                      });
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        height: 48,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            final isSelected = category == selectedCategory;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    selectedCategory = category;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [
                              AppColors.primary400,
                              AppColors.primary700,
                            ],
                          )
                        : null,
                    color: isSelected ? null : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? AppColors.primary.withAlpha(60)
                            : Colors.black.withAlpha(8),
                        blurRadius: isSelected ? 12 : 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    category,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textDark,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCourseCount(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 15, color: AppColors.textDark),
              children: [
                TextSpan(
                  text: '$count ',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                TextSpan(
                  text: count == 1
                      ? (isFr ? 'cours trouvé' : 'course found')
                      : (isFr ? 'cours trouvés' : 'courses found'),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.grid_view,
                  size: 16,
                  color: AppColors.primary400,
                ),
                const SizedBox(width: 6),
                Text(
                  isFr ? 'Grille' : 'Grid',
                  style: TextStyle(
                    color: AppColors.primary400,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off,
              size: 56,
              color: AppColors.primary400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isFr ? 'Aucun cours trouvé' : 'No courses found',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            searchQuery.isNotEmpty
                ? (isFr
                      ? 'Essayez un autre terme de recherche'
                      : 'Try a different search term')
                : (isFr
                      ? 'Aucun cours dans cette catégorie'
                      : 'No courses in this category yet'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          if (searchQuery.isNotEmpty || selectedCategory != 'All')
            OutlinedButton.icon(
              onPressed: () {
                _searchDebounce?.cancel();
                setState(() {
                  searchController.clear();
                  searchQuery = '';
                  selectedCategory = 'All';
                });
              },
              icon: const Icon(Icons.clear_all),
              label: Text(isFr ? 'Effacer les filtres' : 'Clear Filters'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBlogSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary200,
                        AppColors.primary700,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.article_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isFr ? 'Derniers Articles' : 'Latest Articles',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isFr
                            ? 'Restez informé avec nos articles'
                            : 'Stay informed with our articles',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Blog cards list
          SizedBox(
            height: 240,
            child: FutureBuilder<List<Blog>>(
              future: _blogsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2.5,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.wifi_off,
                          size: 32,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isFr
                              ? 'Impossible de charger les articles'
                              : 'Could not load articles',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final blogs = snapshot.data ?? [];
                if (blogs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.article_outlined,
                          size: 32,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isFr
                              ? 'Aucun article pour le moment'
                              : 'No articles yet',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: blogs.length,
                  itemBuilder: (context, index) {
                    final blog = blogs[index];
                    return BlogCard(
                      blog: blog,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BlogDetailPage(
                              slug: blog.slug,
                              previewTitle: blog.title,
                              previewImage: blog.featuredImage,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
