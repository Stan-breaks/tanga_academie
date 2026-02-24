import 'package:flutter/material.dart';
import 'package:tanga_acadamie/data_fetcher.dart';
import 'package:tanga_acadamie/screens/shared/course_card.dart';
import 'package:tanga_acadamie/screens/shared/course_details_page.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';

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

  @override
  void initState() {
    super.initState();
    coursesFuture = fetchCourses();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: FutureBuilder(
        future: coursesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    color: Colors.blueAccent,
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isFr ? 'Découverte des cours...' : 'Discovering courses...',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isFr ? 'Quelque chose a mal tourné' : 'Something went wrong',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: TextStyle(color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        coursesFuture = fetchCourses();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: Text(isFr ? 'Réessayer' : 'Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
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
          } else {
            final courses = snapshot.data!['data'] as List;

            if (!_animationController.isCompleted) {
              _animationController.forward();
            }

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
                color: Colors.blueAccent,
                onRefresh: () async {
                  setState(() {
                    coursesFuture = fetchCourses();
                  });
                },
                child: CustomScrollView(
                  slivers: [
                    // Header Section
                    SliverToBoxAdapter(
                      child: SizedBox(
                        width: 500,
                        height: 100,
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
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio: 0.95,
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
                      Colors.blueAccent.shade200,
                      Colors.blueAccent.shade700,
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
                      'Explore Courses',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      isFr ? 'Trouvez votre prochain cours' : 'Find your next learning journey',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
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
          onChanged: (value) {
            setState(() {
              searchQuery = value;
            });
          },
          decoration: InputDecoration(
            hintText: isFr ? 'Rechercher des cours...' : 'Search courses...',
            hintStyle: TextStyle(color: Colors.grey.shade500),
            prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
            suffixIcon: searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey.shade500),
                    onPressed: () {
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
                              Colors.blueAccent.shade400,
                              Colors.blueAccent.shade700,
                            ],
                          )
                        : null,
                    color: isSelected ? null : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? Colors.blueAccent.withAlpha(60)
                            : Colors.black.withAlpha(8),
                        blurRadius: isSelected ? 12 : 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    category,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey.shade700,
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
              style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
              children: [
                TextSpan(
                  text: '$count ',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                TextSpan(text: count == 1 ? (isFr ? 'cours trouvé' : 'course found') : (isFr ? 'cours trouvés' : 'courses found')),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.grid_view,
                  size: 16,
                  color: Colors.blueAccent.shade400,
                ),
                const SizedBox(width: 6),
                Text(
                  'Grid',
                  style: TextStyle(
                    color: Colors.blueAccent.shade400,
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
              color: Colors.blueAccent.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off,
              size: 56,
              color: Colors.blueAccent.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isFr ? 'Aucun cours trouvé' : 'No courses found',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            searchQuery.isNotEmpty
                ? (isFr ? 'Essayez un autre terme de recherche' : 'Try a different search term')
                : (isFr ? 'Aucun cours dans cette catégorie' : 'No courses in this category yet'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          if (searchQuery.isNotEmpty || selectedCategory != 'All')
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  searchController.clear();
                  searchQuery = '';
                  selectedCategory = 'All';
                });
              },
              icon: const Icon(Icons.clear_all),
              label: Text(isFr ? 'Effacer les filtres' : 'Clear Filters'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blueAccent,
                side: const BorderSide(color: Colors.blueAccent),
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
}
