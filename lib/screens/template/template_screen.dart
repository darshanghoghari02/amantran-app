import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/template_model.dart';
import '../../widgets/translated_text.dart';
import 'template_detail_screen.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../widgets/top_notification.dart';
import '../../widgets/premium_badge.dart';
import '../../utils/image_resolver.dart';

class TemplateScreen extends StatefulWidget {
  final String title;
  final List<TemplateModel> templates;

  const TemplateScreen({
    super.key,
    required this.title,
    required this.templates,
  });

  @override
  State<TemplateScreen> createState() => _TemplateScreenState();
}

class _TemplateScreenState extends State<TemplateScreen> {
  int? openMenuIndex;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final favoritesProvider = context.watch<FavoritesProvider>();
    final subProvider = context.watch<SubscriptionProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFFCF9F9),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
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
                          child: const Icon(Icons.arrow_back, size: 20, color: Colors.black87),
                        ),
                      ),
                      const SizedBox(width: 16),
                      TranslatedText(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Grid
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
                    itemCount: widget.templates.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 20,
                      childAspectRatio: 0.65,
                    ),
                    itemBuilder: (context, index) {
                      final template = widget.templates[index];
                      final isMenuOpen = openMenuIndex == index;
                      final isUnlocked = subProvider.isTemplateUnlocked(template);

                      return GestureDetector(
                        onTap: () {
                          if (openMenuIndex != null) {
                            setState(() => openMenuIndex = null);
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TemplateDetailScreen(
                                categoryName: widget.title,
                                template: template,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: ClipRRect(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                          child: isNetworkImage(template.thumbnail)
                                              ? Image.network(resolveImageUrl(template.thumbnail), fit: BoxFit.cover)
                                              : Image.asset(template.thumbnail, fit: BoxFit.cover),
                                        ),
                                    ),
                                    // Action icons overlay
                                    Positioned(
                                      bottom: 8,
                                      right: 8,
                                      child: isMenuOpen 
                                          ? _buildExpandedMenu(index, template, favoritesProvider) 
                                          : _buildFavoriteAndMenu(index, template, favoritesProvider),
                                    ),
                                    if (template.isPremium)
                                      const Positioned(
                                        top: 10,
                                        right: 10,
                                        child: PremiumBadge(
                                          fontSize: 7.5,
                                          iconSize: 9.0,
                                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TranslatedText(
                                      template.title.isEmpty
                                          ? "Template ${index + 1}"
                                          : template.title.split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' '),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 2),
                                     if (template.isPremium) ...[
                                       Text(
                                         isUnlocked
                                             ? lang.planActive
                                             : ((template.singlePurchasePrice != null && template.singlePurchasePrice! > 0)
                                                 ? "₹${template.singlePurchasePrice!.toInt()} Lifetime"
                                                 : "Included in Premium"),
                                         style: TextStyle(
                                           fontSize: 11,
                                           fontWeight: FontWeight.w600,
                                           color: isUnlocked
                                               ? Colors.green.shade600
                                               : ((template.singlePurchasePrice != null && template.singlePurchasePrice! > 0)
                                                   ? const Color(0xFFF94C66)
                                                   : Colors.grey.shade500),
                                         ),
                                       ),
                                     ] else ...[
                                      Text(
                                        "Free",
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green.shade600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Floating Bottom Navigation Bar
          Positioned(
            bottom: 25,
            left: 45,
            right: 45,
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(35),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(Icons.home_outlined, lang.home, true, () {
                    Navigator.pop(context, 0);
                  }),
                  _buildNavItem(Icons.folder_open_outlined, lang.yourDesign, false, () {
                    Navigator.pop(context, 1);
                  }),
                  _buildNavItem(Icons.favorite_border, lang.favorites, false, () {
                    Navigator.pop(context, 2);
                  }, badgeCount: favoritesProvider.count),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteAndMenu(int index, TemplateModel template, FavoritesProvider favorites) {
    final isFavorite = favorites.isFavorite(template);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            final isFav = context.read<FavoritesProvider>().isFavorite(template);
            context.read<FavoritesProvider>().toggleFavorite(template);
            TopNotification.show(context, 
              message: isFav ? "Removed from favorites" : "Added to favorites",
              type: isFav ? NotificationType.info : NotificationType.success);
          },
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border, 
              size: 18, 
              color: isFavorite ? const Color(0xFFF94C66) : Colors.black87
            ),
          ),
        ),
        const SizedBox(width: 8),
        _buildThreeDots(index),
      ],
    );
  }

  Widget _buildThreeDots(int index) {
    return GestureDetector(
      onTap: () {
        setState(() {
          openMenuIndex = index;
        });
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.more_horiz, size: 18, color: Colors.black87),
      ),
    );
  }

  Widget _buildExpandedMenu(int index, TemplateModel template, FavoritesProvider favorites) {
    final isFavorite = favorites.isFavorite(template);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildMenuButton(
          isFavorite ? Icons.favorite : Icons.favorite_border, 
          () {
            final isFav = context.read<FavoritesProvider>().isFavorite(template);
            context.read<FavoritesProvider>().toggleFavorite(template);
            setState(() => openMenuIndex = null);
            TopNotification.show(context, 
              message: isFav ? "Removed from favorites" : "Added to favorites",
              type: isFav ? NotificationType.info : NotificationType.success);
          }, 
          color: isFavorite ? const Color(0xFFF94C66) : Colors.black87
        ),
        const SizedBox(height: 8),
        _buildMenuButton(Icons.remove_red_eye_outlined, () {
          showDialog(
            context: context,
            builder: (_) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: isNetworkImage(template.thumbnail)
                    ? Image.network(resolveImageUrl(template.thumbnail), fit: BoxFit.contain)
                    : Image.asset(template.thumbnail, fit: BoxFit.contain),
              ),
            ),
          );
          setState(() => openMenuIndex = null);
        }),
        const SizedBox(height: 8),
        _buildMenuButton(Icons.close, () {
          setState(() => openMenuIndex = null);
        }),
      ],
    );
  }

  Widget _buildMenuButton(IconData icon, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 16, color: color ?? Colors.black87),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isSelected, VoidCallback onTap, {int badgeCount = 0}) {
    final color = isSelected ? const Color(0xFFF94C66) : Colors.black54;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected && icon == Icons.home_outlined ? Icons.home : icon,
                  color: color,
                  size: 26,
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -8,
                    top: -5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF94C66),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
