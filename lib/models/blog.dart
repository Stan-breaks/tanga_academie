/// Blog model for the public blog feature and admin management.
class Blog {
  final String id;
  final String title;
  final String slug;
  final String excerpt;
  final String content;
  final String category;
  final String coverImage;
  final String featuredImage;
  final String status;
  final List<String> tags;
  final int views;
  final String createdAt;
  final String updatedAt;
  final String metaTitle;
  final String metaDescription;
  final bool isCommentEnabled;
  final BlogAuthor? author;

  Blog({
    required this.id,
    required this.title,
    required this.slug,
    this.excerpt = '',
    this.content = '',
    this.category = '',
    this.coverImage = '',
    this.featuredImage = '',
    this.status = 'draft',
    this.tags = const [],
    this.views = 0,
    this.createdAt = '',
    this.updatedAt = '',
    this.metaTitle = '',
    this.metaDescription = '',
    this.isCommentEnabled = true,
    this.author,
  });

  /// The best available image path (featuredImage for admin, coverImage for public).
  String get imageUrl => featuredImage.isNotEmpty ? featuredImage : coverImage;

  factory Blog.fromJson(Map<String, dynamic> json) {
    return Blog(
      id: json['_id'] ?? '',
      title: json['title'] ?? '',
      slug: json['slug'] ?? '',
      excerpt: json['excerpt'] ?? '',
      content: json['content'] ?? '',
      category: json['category'] ?? '',
      coverImage: json['coverImage'] ?? '',
      featuredImage: json['featuredImage'] ?? '',
      status: json['status'] ?? 'draft',
      tags: (json['tags'] as List<dynamic>?)
              ?.map((t) => t.toString())
              .toList() ??
          [],
      views: json['views'] ?? 0,
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
      metaTitle: json['metaTitle'] ?? '',
      metaDescription: json['metaDescription'] ?? '',
      isCommentEnabled: json['isCommentEnabled'] ?? true,
      author: json['author'] != null && json['author'] is Map
          ? BlogAuthor.fromJson(json['author'])
          : null,
    );
  }
}

class BlogAuthor {
  final String firstName;
  final String lastName;
  final String? profile;
  final String? bio;
  final String? skill;
  final String? email;

  BlogAuthor({
    required this.firstName,
    required this.lastName,
    this.profile,
    this.bio,
    this.skill,
    this.email,
  });

  factory BlogAuthor.fromJson(Map<String, dynamic> json) {
    return BlogAuthor(
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      profile: json['profile'],
      bio: json['bio'],
      skill: json['skill'],
      email: json['email'],
    );
  }

  String get fullName => '$firstName $lastName';
}
