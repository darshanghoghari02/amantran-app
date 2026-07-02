import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/template_model.dart';
import '../../models/page_model.dart';
import '../../widgets/translated_text.dart';

import '../profile/invitation_language_screen.dart';
import '../../providers/language_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/app_data_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../widgets/top_notification.dart';
import '../../widgets/premium_badge.dart';
import '../../widgets/subscription_bottom_sheet.dart';
import '../../widgets/app_image.dart';
import '../../utils/image_resolver.dart';
import 'package:cached_network_image/cached_network_image.dart';

class TemplateDetailScreen extends StatefulWidget {
  final String categoryName;
  final TemplateModel template;

  const TemplateDetailScreen({
    super.key,
    required this.categoryName,
    required this.template,
  });

  @override
  State<TemplateDetailScreen> createState() => _TemplateDetailScreenState();
}

class _TemplateDetailScreenState extends State<TemplateDetailScreen> {
  final PageController _pageController = PageController(viewportFraction: 0.85);
  int _currentPage = 0;
  List<PageModel> _pages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPages();
  }

  Future<void> _loadPages() async {
    try {
      final appData = context.read<AppDataProvider>();
      
      // Load cached pages first to show something instantly
      final cachedPages = await appData.getTemplatePagesCachedFirst(widget.template.id);
      if (mounted && cachedPages.isNotEmpty) {
        setState(() {
          _pages = cachedPages;
          _isLoading = false;
        });
        _precachePageImages(cachedPages);
      } else {
        // If no cache, show loading state
        if (mounted) {
          setState(() {
            _isLoading = true;
          });
        }
      }
      
      // Fetch latest template details and pages from server in background (non-blocking)
      appData.refreshTemplateDetails(widget.template.id).then((_) {
        if (mounted) {
          appData.getTemplatePagesCachedFirst(widget.template.id).then((freshPages) {
            if (mounted && freshPages.isNotEmpty) {
              setState(() {
                _pages = freshPages;
                _isLoading = false;
              });
              _precachePageImages(freshPages);
            }
          });
        }
      }).catchError((e) {
        print("Error refreshing template details: $e");
        // Even if refresh fails, keep showing cached data
        if (mounted && _pages.isEmpty) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      print("Error loading pages in TemplateDetailScreen: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _precachePageImages(List<PageModel> pages) {
    if (!mounted) return;
    // Only precache the first page to improve initial load performance
    if (pages.isNotEmpty && pages[0].backgroundImage.isNotEmpty) {
      final url = resolveImageUrl(pages[0].backgroundImage);
      if (url.startsWith('http')) {
        precacheImage(
          CachedNetworkImageProvider(url, maxWidth: 680),
          context,
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final template = context.watch<AppDataProvider>().getTemplateById(widget.template.id) ?? widget.template;
    final subProvider = context.watch<SubscriptionProvider>();
    final int totalPages = _pages.isNotEmpty ? _pages.length : 1;

    return Scaffold(
      backgroundColor: const Color(0xFFFCF9F9),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Custom App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.arrow_back,
                          size: 20, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TranslatedText(
                      widget.categoryName.isNotEmpty
                          ? widget.categoryName
                          : lang.templateDetail,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      final isFav = context
                          .read<FavoritesProvider>()
                          .isFavorite(template);
                      context
                          .read<FavoritesProvider>()
                          .toggleFavorite(template);
                      TopNotification.show(context,
                          message: isFav
                              ? lang.removedFromFavorites
                              : lang.addedToFavorites,
                          type: isFav
                              ? NotificationType.info
                              : NotificationType.success);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                          context
                                  .watch<FavoritesProvider>()
                                  .isFavorite(template)
                              ? Icons.favorite
                              : Icons.favorite_border,
                          size: 20,
                          color: context
                                  .watch<FavoritesProvider>()
                                  .isFavorite(template)
                              ? const Color(0xFFF94C66)
                              : Colors.black87),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Carousel / PageView Loading
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(color: Color(0xFFF94C66)),
                          const SizedBox(height: 16),
                          Text(lang.loadingDynamicPages, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 400,
                            child: PageView.builder(
                              controller: _pageController,
                              itemCount: totalPages,
                              onPageChanged: (index) {
                                setState(() {
                                  _currentPage = index;
                                });
                              },
                              itemBuilder: (context, index) {
                                final String backgroundUrl = _pages.isNotEmpty 
                                    ? _pages[index].backgroundImage 
                                    : template.thumbnail;

                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin: EdgeInsets.only(
                                    right: 16,
                                    top: _currentPage == index ? 0 : 30,
                                    bottom: _currentPage == index ? 0 : 30,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 15,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: AppImage(
                                      src: backgroundUrl,
                                      fit: BoxFit.cover,
                                      width: 340,
                                      height: 600,
                                      errorWidget: Image.asset(
                                        'assets/images/banner_image.png',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Pagination Text
                          Center(
                            child: Text(
                              "${_currentPage + 1}/$totalPages",
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Template Details
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TranslatedText(
                                        template.title.isEmpty
                                            ? lang.weddingTemplate
                                            : template.title.split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' '),
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    if (template.isPremium) ...[
                                      const SizedBox(width: 8),
                                      const PremiumBadge(
                                        fontSize: 9.0,
                                        iconSize: 11.0,
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  lang.templateDescription,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  lang.features,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFF94C66),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildFeatureRow(Icons.edit_outlined, lang.feature1),
                                const SizedBox(height: 8),
                                _buildFeatureRow(Icons.file_download_outlined, lang.feature2),
                                const SizedBox(height: 8),
                                _buildFeatureRow(Icons.share_outlined, lang.feature3),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
            ),

            // Customize Button
            if (!_isLoading)
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
                      final isUnlocked = subProvider.isTemplateUnlocked(template);
                      if (template.isPremium && !isUnlocked) {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => SubscriptionBottomSheet(template: template),
                        );
                        return;
                      }

                      final langProvider = context.read<LanguageProvider>();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => InvitationLanguageScreen(
                            selectedLanguages: langProvider.invitationLanguages.toList(),
                            template: template,
                            isSingleSelect: true,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF94C66),
                      foregroundColor: Colors.white,
                      elevation: 5,
                      shadowColor: const Color(0xFFF94C66).withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      lang.customizeTemplate,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.black54),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
