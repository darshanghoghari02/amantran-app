import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart' show AssetManifest;

// 🔴 MODELS
import '../../models/template_model.dart';
import '../../models/user_design.dart';

// 🔴 SCREENS
import '../editor/editor_screen.dart';
import '../template/template_screen.dart';
import '../template/template_detail_screen.dart';
import '../profile/profile_screen.dart';
import '../profile/edit_profile_screen.dart';
import '../designs/all_designs_screen.dart';
import '../../providers/language_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/designs_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../widgets/design_cards.dart';
import '../../widgets/premium_badge.dart';
import '../guests/guest_screen.dart';
import '../../widgets/top_notification.dart';
import '../../widgets/design_pdf_share_dialog.dart';
import '../../providers/app_data_provider.dart';
import '../../utils/image_resolver.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch here to ensure whole screen rebuilds on change
    final lang = context.watch<LanguageProvider>();
    final user = context.watch<UserProvider>();
    final designsProvider = context.watch<DesignsProvider>();
    final favoritesProvider = context.watch<FavoritesProvider>();

    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFCF9F9),
        body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: [
              _buildHomeTab(lang, user, context),
              _buildDraftsTab(lang, designsProvider),
              _buildFavoritesTab(lang, favoritesProvider),
              _buildGuestsTab(lang),
            ],
          ),

          // Custom Bottom Navigation Bar
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 10,
            child: Container(
              height: 65,
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
                  _buildNavItem(Icons.home_rounded, lang.home, 0),
                  _buildNavItem(Icons.description_outlined, lang.yourDesign, 1),
                  _buildNavItem(Icons.favorite_border_rounded, lang.favorites, 2, badgeCount: favoritesProvider.count),
                  _buildNavItem(Icons.groups_outlined, lang.guests, 3),
                ],
              ),
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildHomeTab(LanguageProvider lang, UserProvider user, BuildContext context) {
    final appData = context.watch<AppDataProvider>();
    final categories = appData.categories;
    
    return SafeArea(
      child: RefreshIndicator(
        color: const Color(0xFFF94C66),
        onRefresh: () async {
          appData.retryInit();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ProfileScreen()),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(width: 20, height: 2, color: const Color(0xFFF94C66), margin: const EdgeInsets.only(bottom: 5)),
                            Container(width: 14, height: 2, color: const Color(0xFFF94C66), margin: const EdgeInsets.only(bottom: 5)),
                            Container(width: 8, height: 2, color: const Color(0xFFF94C66)),
                          ],
                        ),
                      ),
                    ),
                    Text(
                      lang.appTitle,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                        );
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey,
                          image: DecorationImage(
                            image: user.profileImagePath != null
                                ? (user.profileImagePath!.startsWith('http')
                                    ? NetworkImage(user.profileImagePath!) as ImageProvider
                                    : FileImage(File(user.profileImagePath!)) as ImageProvider)
                                : const AssetImage('assets/images/banner_image.png'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
  
              const SizedBox(height: 20),
  
              // Welcome Text
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  lang.hello(user.name), 
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  lang.subtitle, 
                  style: const TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w500)
                ),
              ),
  
              const SizedBox(height: 25),
  
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  height: 55,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(27.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      )
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: lang.searchHint,
                      hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(left: 12, right: 8),
                        child: Icon(Icons.search, color: Color(0xFFF94C66), size: 24),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.black38,
                                size: 20,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ),
  
              const SizedBox(height: 35),
  
              // Sections
              if (_searchQuery.isEmpty) ...[
                if (appData.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Color(0xFFF94C66)),
                          SizedBox(height: 16),
                          Text("Loading dynamic invitation designs...", style: TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                    ),
                  )
                else if (appData.hasError)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_rounded, size: 50, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            appData.errorMessage ?? "An error occurred",
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.black54, fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => appData.retryInit(),
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text("Retry"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF94C66),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (appData.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 50, color: Colors.grey),
                          SizedBox(height: 16),
                          Text("No templates found in database.", style: TextStyle(color: Colors.grey, fontSize: 14)),
                        ],
                      ),
                    ),
                  )
                else
                  ...categories.map((cat) {
                    final catTemplates = appData.getTemplatesByCategory(cat.id);
                    if (catTemplates.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 25),
                      child: _buildSection(cat.name, catTemplates),
                    );
                  }).toList(),
              ] else ...[
                _buildSearchResults(lang, appData),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDraftsTab(LanguageProvider lang, DesignsProvider designsProvider) {
    final drafts = designsProvider.drafts;
    final completed = designsProvider.completed;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _selectedIndex = 0),
                  icon: const Icon(Icons.arrow_back_ios, size: 20),
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 16),
                Text(lang.yourDesign, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (drafts.isNotEmpty) ...[
                    _buildUserDesignHorizontalSection(lang.drafts, drafts, lang),
                    const SizedBox(height: 25),
                  ],
                  if (completed.isNotEmpty) ...[
                    _buildUserDesignGridSection(lang.yourDesigns, completed, lang),
                  ],
                  if (drafts.isEmpty && completed.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 100),
                      child: Center(child: Text(lang.noDraftsYet, style: const TextStyle(color: Colors.grey))),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesTab(LanguageProvider lang, FavoritesProvider favoritesProvider) {
    final favorites = favoritesProvider.favorites;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _selectedIndex = 0),
                  icon: const Icon(Icons.arrow_back_ios, size: 20),
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 16),
                Text(lang.favorites, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
          ),
          Expanded(
            child: favorites.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.favorite_border, size: 50, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(lang.noFavoritesYet, style: const TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
                    itemCount: favorites.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 20,
                      childAspectRatio: 0.75,
                    ),
                    itemBuilder: (context, index) {
                      final template = favorites[index];
                      return _buildTemplateCard(template.title, template.thumbnail, template, 'Favorites', lang, isGrid: true);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestsTab(LanguageProvider lang) {
    return const SizedBox.shrink();
  }

  Widget _buildNavItem(IconData icon, String label, int index, {int badgeCount = 0}) {
    bool isSelected = _selectedIndex == index;
    final color = isSelected ? const Color(0xFFF94C66) : Colors.black38;
    return GestureDetector(
      onTap: () {
        if (index == 3) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const GuestScreen()));
        } else {
          setState(() => _selectedIndex = index);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: color, size: 26),
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
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<TemplateModel> items) {
    final lang = context.watch<LanguageProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              GestureDetector(
                onTap: () async {
                   final targetIndex = await Navigator.push<int>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TemplateScreen(
                        title: title,
                        templates: items,
                      ),
                    ),
                  );
                  if (targetIndex != null && mounted) {
                    setState(() {
                      _selectedIndex = targetIndex;
                    });
                  }
                },
                child: Row(
                  children: [
                    Text(lang.seeAll, style: const TextStyle(color: Color(0xFFF94C66), fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_circle_right, color: Color(0xFFF94C66), size: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        SizedBox(
          height: 250,
          child: ListView.builder(
            padding: const EdgeInsets.only(left: 20),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              return _buildTemplateCard(items[index].title, items[index].thumbnail, items[index], title, lang);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults(LanguageProvider lang, AppDataProvider appData) {
    final allTemplates = appData.allTemplates;
    
    final results = allTemplates.where((t) => t.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(lang.noTemplatesFound, style: const TextStyle(color: Colors.black54)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lang.searchResults, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 15),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: results.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 20,
              childAspectRatio: 0.75,
            ),
            itemBuilder: (context, index) {
              return _buildTemplateCard(results[index].title, results[index].thumbnail, results[index], 'Search Result', lang, isGrid: true);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(String name, String imagePath, TemplateModel template, String categoryName, LanguageProvider lp, {bool isGrid = false}) {
    final subProvider = context.watch<SubscriptionProvider>();
    final isUnlocked = subProvider.isTemplateUnlocked(template);

    return Container(
      width: isGrid ? null : 160,
      margin: isGrid ? EdgeInsets.zero : const EdgeInsets.only(right: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TemplateDetailScreen(
                      categoryName: categoryName,
                      template: template,
                    ),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  image: DecorationImage(
                    image: isNetworkImage(imagePath) 
                        ? NetworkImage(resolveImageUrl(imagePath)) 
                        : AssetImage(cleanAssetPath(imagePath)) as ImageProvider, 
                    fit: BoxFit.cover,
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5)),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 10,
                      left: 10,
                      child: GestureDetector(
                        onTap: () {
                          final isFav = context.read<FavoritesProvider>().isFavorite(template);
                          context.read<FavoritesProvider>().toggleFavorite(template);
                          TopNotification.show(context, 
                            message: isFav ? lp.removedFromFavorites : lp.addedToFavorites,
                            type: isFav ? NotificationType.info : NotificationType.success);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: Icon(
                            context.watch<FavoritesProvider>().isFavorite(template) ? Icons.favorite : Icons.favorite_border, 
                            size: 16, 
                            color: context.watch<FavoritesProvider>().isFavorite(template) ? const Color(0xFFF94C66) : Colors.black38
                          ),
                        ),
                      ),
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
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          if (template.isPremium) ...[
            Text(
              isUnlocked
                  ? lp.planActive
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
    );
  }

  Widget _buildUserDesignHorizontalSection(String title, List<UserDesign> items, LanguageProvider lp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AllDesignsScreen(title: title, isDrafts: true),
                    ),
                  );
                },
                child: Text(
                  lp.seeAll,
                  style: const TextStyle(color: Color(0xFFF94C66), fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        SizedBox(
          height: 200,
          child: ListView.builder(
            padding: const EdgeInsets.only(left: 20),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final design = items[index];
              return Container(
                width: 140,
                margin: const EdgeInsets.only(right: 15),
                child: DraftCard(
                  design: design,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditorScreen(
                          template: design.template,
                          designId: design.id,
                          initialElements: design.elements,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserDesignGridSection(String title, List<UserDesign> items, LanguageProvider lp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AllDesignsScreen(title: title, isDrafts: false),
                    ),
                  );
                },
                child: Text(
                  lp.seeAll,
                  style: const TextStyle(color: Color(0xFFF94C66), fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.8,
            crossAxisSpacing: 15,
            mainAxisSpacing: 20,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final design = items[index];
            return CompletedDesignCard(
              design: design,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditorScreen(
                      template: design.template,
                      designId: design.id,
                      initialElements: design.elements,
                    ),
                  ),
                );
              },
              onDelete: () {
                _showDeleteDesignConfirm(design);
              },
              onShare: () {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => DesignPdfShareDialog(design: design),
                );
              },
            );
          },
        ),
      ],
    );
  }


  void _showDeleteDesignConfirm(UserDesign design) {
    final lang = context.read<LanguageProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.deleteDesign),
        content: Text(lang.deleteDesignConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(lang.cancel)),
          TextButton(
            onPressed: () {
              context.read<DesignsProvider>().deleteDesign(design.id);
              Navigator.pop(ctx);
              TopNotification.show(context, message: lang.designDeleted, type: NotificationType.info);
            },
            child: Text(lang.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
