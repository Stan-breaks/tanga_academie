import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tanga_acadamie/api_config.dart';
import 'package:tanga_acadamie/models/blog.dart';
import 'package:tanga_acadamie/services/admin_blog_service.dart';
import 'package:tanga_acadamie/core/language/language_provider.dart';

/// Create or edit a blog post.
class AdminBlogFormPage extends StatefulWidget {
  final Blog? blog; // null = create mode, non-null = edit mode

  const AdminBlogFormPage({super.key, this.blog});

  @override
  State<AdminBlogFormPage> createState() => _AdminBlogFormPageState();
}

class _AdminBlogFormPageState extends State<AdminBlogFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _excerptController = TextEditingController();
  final _contentController = TextEditingController();
  final _categoryController = TextEditingController();
  final _tagsController = TextEditingController();
  final _metaTitleController = TextEditingController();
  final _metaDescriptionController = TextEditingController();

  String _status = 'draft';
  bool _isCommentEnabled = true;
  File? _imageFile;
  bool _isSaving = false;

  bool get _isEditMode => widget.blog != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final b = widget.blog!;
      _titleController.text = b.title;
      _excerptController.text = b.excerpt;
      _contentController.text = b.content;
      _categoryController.text = b.category;
      _tagsController.text = b.tags.join(', ');
      _metaTitleController.text = b.metaTitle;
      _metaDescriptionController.text = b.metaDescription;
      _status = b.status;
      _isCommentEnabled = b.isCommentEnabled;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _excerptController.dispose();
    _contentController.dispose();
    _categoryController.dispose();
    _tagsController.dispose();
    _metaTitleController.dispose();
    _metaDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isFr ? 'Choisir une image' : 'Choose Image',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _imageSourceButton(
                    icon: Icons.photo_library,
                    label: isFr ? 'Galerie' : 'Gallery',
                    onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _imageSourceButton(
                    icon: Icons.camera_alt,
                    label: isFr ? 'Caméra' : 'Camera',
                    onTap: () => Navigator.pop(ctx, ImageSource.camera),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picked = await picker.pickImage(source: source, maxWidth: 1200);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
    }
  }

  Widget _imageSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.blueAccent.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blueAccent.withAlpha(40)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Colors.blueAccent),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: Colors.blueAccent)),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      if (_isEditMode) {
        await AdminBlogService.updateBlog(
          id: widget.blog!.id,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          excerpt: _excerptController.text.trim(),
          category: _categoryController.text.trim(),
          tags: _tagsController.text.trim(),
          status: _status,
          metaTitle: _metaTitleController.text.trim(),
          metaDescription: _metaDescriptionController.text.trim(),
          isCommentEnabled: _isCommentEnabled,
          featuredImage: _imageFile,
        );
      } else {
        await AdminBlogService.createBlog(
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          excerpt: _excerptController.text.trim(),
          category: _categoryController.text.trim(),
          tags: _tagsController.text.trim(),
          status: _status,
          metaTitle: _metaTitleController.text.trim(),
          metaDescription: _metaDescriptionController.text.trim(),
          isCommentEnabled: _isCommentEnabled,
          featuredImage: _imageFile,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode
                ? (isFr
                    ? 'Article mis à jour avec succès'
                    : 'Blog updated successfully')
                : (isFr
                    ? 'Article créé avec succès'
                    : 'Blog created successfully')),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${isFr ? 'Erreur' : 'Error'}: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode
            ? (isFr ? 'Modifier l\'article' : 'Edit Blog')
            : (isFr ? 'Nouvel article' : 'New Blog')),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.blueAccent,
                      ),
                    )
                  : const Icon(Icons.check, size: 18),
              label: Text(
                _isSaving
                    ? (isFr ? 'Enregistrement...' : 'Saving...')
                    : (isFr ? 'Enregistrer' : 'Save'),
              ),
              style: TextButton.styleFrom(foregroundColor: Colors.blueAccent),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.grey.shade50,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Featured Image
            _buildImageSection(),
            const SizedBox(height: 24),

            // Title
            _buildTextField(
              controller: _titleController,
              label: isFr ? 'Titre' : 'Title',
              hint: isFr ? 'Entrez le titre de l\'article' : 'Enter blog title',
              icon: Icons.title,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return isFr ? 'Le titre est requis' : 'Title is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Excerpt
            _buildTextField(
              controller: _excerptController,
              label: isFr ? 'Extrait' : 'Excerpt',
              hint: isFr
                  ? 'Résumé court de l\'article'
                  : 'Short summary of the blog',
              icon: Icons.short_text,
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Content
            _buildTextField(
              controller: _contentController,
              label: isFr ? 'Contenu' : 'Content',
              hint: isFr
                  ? 'Écrivez le contenu de votre article...'
                  : 'Write your blog content...',
              icon: Icons.article,
              maxLines: 12,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return isFr ? 'Le contenu est requis' : 'Content is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Category + Status row
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _categoryController,
                    label: isFr ? 'Catégorie' : 'Category',
                    hint: isFr ? 'ex: Technologie' : 'e.g. Technology',
                    icon: Icons.category,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _buildStatusDropdown()),
              ],
            ),
            const SizedBox(height: 16),

            // Tags
            _buildTextField(
              controller: _tagsController,
              label: isFr ? 'Tags' : 'Tags',
              hint: isFr
                  ? 'Tags séparés par des virgules'
                  : 'Comma-separated tags',
              icon: Icons.tag,
            ),
            const SizedBox(height: 24),

            // SEO Section
            _buildSectionTitle(isFr ? 'SEO (Optionnel)' : 'SEO (Optional)'),
            const SizedBox(height: 12),

            _buildTextField(
              controller: _metaTitleController,
              label: isFr ? 'Meta Titre' : 'Meta Title',
              hint: isFr ? 'Titre pour les moteurs de recherche' : 'Title for search engines',
              icon: Icons.search,
            ),
            const SizedBox(height: 12),

            _buildTextField(
              controller: _metaDescriptionController,
              label: isFr ? 'Meta Description' : 'Meta Description',
              hint: isFr
                  ? 'Description pour les moteurs de recherche'
                  : 'Description for search engines',
              icon: Icons.description,
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Comment toggle
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: SwitchListTile(
                title: Text(
                  isFr ? 'Activer les commentaires' : 'Enable Comments',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                ),
                value: _isCommentEnabled,
                activeThumbColor: Colors.blueAccent,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  setState(() => _isCommentEnabled = val);
                },
              ),
            ),

            const SizedBox(height: 80), // Space for FAB
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    final existingImage =
        _isEditMode ? ApiConfig.getImageUrl(widget.blog!.imageUrl) : '';
    final hasExisting = existingImage.isNotEmpty && _imageFile == null;

    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.shade300,
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: _imageFile != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(_imageFile!, fit: BoxFit.cover),
                  _buildImageOverlay(),
                ],
              )
            : hasExisting
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        existingImage,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _buildImagePickerPlaceholder(),
                      ),
                      _buildImageOverlay(),
                    ],
                  )
                : _buildImagePickerPlaceholder(),
      ),
    );
  }

  Widget _buildImageOverlay() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withAlpha(120)],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              isFr ? 'Changer l\'image' : 'Change Image',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePickerPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_outlined,
            size: 48, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Text(
          isFr ? 'Ajouter une image à la une' : 'Add Featured Image',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isFr ? 'Appuyez pour sélectionner' : 'Tap to select',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: maxLines > 1 ? null : Icon(icon, size: 20),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: _status,
        decoration: InputDecoration(
          labelText: isFr ? 'Statut' : 'Status',
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
        ),
        items: [
          DropdownMenuItem(
            value: 'draft',
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: Colors.orange, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(isFr ? 'Brouillon' : 'Draft', style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
          DropdownMenuItem(
            value: 'published',
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: Colors.green, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(isFr ? 'Publié' : 'Published', style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
          DropdownMenuItem(
            value: 'archived',
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: Colors.grey, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(isFr ? 'Archivé' : 'Archived', style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
        onChanged: (val) {
          if (val != null) setState(() => _status = val);
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.blueAccent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
