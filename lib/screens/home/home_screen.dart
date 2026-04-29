import 'package:flutter/material.dart';

import '../template/template_screen.dart';
import '../../features/guests/screens/guest_list_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFFDF7F7),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          "Wedding Kankotri",
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
      ),

      // 🔥 STICKY CTA BUTTON (BOTTOM)
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TemplateScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Create New Kankotri",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // 🔴 SUBTITLE
                const Text(
                  "Create beautiful Gujarati wedding invitations easily",
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),

                const SizedBox(height: 14),

                // 🔥 FULL WIDTH BANNER (25% HEIGHT)
                Container(
                  width: double.infinity,
                  height: size.height * 0.25,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    image: const DecorationImage(
                      image: AssetImage("assets/images/banner_image.png"),
                      fit: BoxFit.cover,
                    ),
                  ),

                  // 🔥 OVERLAY TEXT
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.35),
                          Colors.transparent,
                        ],
                        begin: Alignment.bottomLeft,
                        end: Alignment.topRight,
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: const Align(
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        "Design Your\nWedding Invitation",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 🔴 TITLE
                const Text(
                  "Quick Actions",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 12),

                // 🔥 GRID (RESPONSIVE)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;

                    int crossAxisCount = width > 800 ? 4 : 2;

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 4,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.3,
                      ),
                      itemBuilder: (context, index) {
                        final items = [
                          {
                            "icon": Icons.image,
                            "title": "Templates",
                            "color": Colors.pink,
                            "onTap": () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const TemplateScreen(),
                                  ),
                                ),
                          },
                          {
                            "icon": Icons.people,
                            "title": "Guests",
                            "color": Colors.orange,
                            "onTap": () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const GuestListScreen(),
                                  ),
                                ),
                          },
                          {
                            "icon": Icons.picture_as_pdf,
                            "title": "Export PDF",
                            "color": Colors.red,
                            "onTap": () =>
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Open Preview Screen"),
                                  ),
                                ),
                          },
                          {
                            "icon": Icons.share,
                            "title": "Share",
                            "color": Colors.green,
                            "onTap": () =>
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Coming Soon")),
                                ),
                          },
                        ];

                        final item = items[index];

                        return _actionCard(
                          icon: item["icon"] as IconData,
                          title: item["title"] as String,
                          color: item["color"] as Color,
                          onTap: item["onTap"] as VoidCallback,
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 80), // space for bottom button
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🔥 ACTION CARD
  Widget _actionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 26, color: color),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
