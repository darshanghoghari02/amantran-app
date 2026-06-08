import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_design.dart';
import '../../providers/designs_provider.dart';
import '../../providers/language_provider.dart';
import '../editor/editor_screen.dart';
import '../../widgets/design_cards.dart';
import '../../widgets/top_notification.dart';
import 'package:share_plus/share_plus.dart';

class AllDesignsScreen extends StatelessWidget {
  final String title;
  final bool isDrafts;

  const AllDesignsScreen({
    super.key,
    required this.title,
    required this.isDrafts,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final designsProvider = context.watch<DesignsProvider>();
    final designs = isDrafts ? designsProvider.drafts : designsProvider.completed;

    return Scaffold(
      backgroundColor: const Color(0xFFFCF9F9),
      body: SafeArea(
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
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: designs.isEmpty
                  ? Center(
                      child: Text(
                        isDrafts ? lang.noDraftsYet : "No designs yet.",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                      itemCount: designs.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 15,
                        mainAxisSpacing: 20,
                        childAspectRatio: 0.75,
                      ),
                      itemBuilder: (context, index) {
                        final design = designs[index];
                        final onTap = () {
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
                        };

                        if (isDrafts) {
                          return DraftCard(
                            design: design,
                            onTap: onTap,
                            showActions: true,
                            onEdit: onTap,
                            onDelete: () {
                              _showDeleteConfirm(context, design);
                            },
                          );
                        } else {
                          return CompletedDesignCard(
                            design: design,
                            onTap: onTap,
                            onDelete: () {
                              _showDeleteConfirm(context, design);
                            },
                            onShare: () {
                              Share.share('Check out my design: ${design.template.name}');
                            },
                          );
                        }
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }


  void _showDeleteConfirm(BuildContext context, UserDesign design) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Delete Design?",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              const Text(
                "Are you sure you want to delete this design? This action cannot be undone.",
                style: TextStyle(fontSize: 15, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: const BorderSide(color: Colors.black26),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        context.read<DesignsProvider>().deleteDesign(design.id);
                        Navigator.pop(ctx);
                        TopNotification.show(context, message: "Design deleted successfully", type: NotificationType.info);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF94C66),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 4,
                        shadowColor: const Color(0xFFF94C66).withOpacity(0.4),
                      ),
                      child: const Text("Delete", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
