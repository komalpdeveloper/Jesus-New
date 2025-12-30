import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:clientapp/core/theme/palette.dart';
import 'package:clientapp/features/church_admin/presentation/church_radio_admin_page.dart';
import 'package:clientapp/features/church_admin/presentation/church_radio_snippets_admin_page.dart';

class ChurchAdminPage extends StatelessWidget {
  const ChurchAdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDeepBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Church Admin',
          style: GoogleFonts.lora(
            color: kGold,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: kRoyalBlue.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: kRoyalBlue.withValues(alpha: 0.8), width: 2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kRoyalBlue),
                        ),
                        child: const Icon(Icons.church, color: kGold, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Church Management',
                              style: GoogleFonts.cinzel(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: kGold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Manage sermons, stories, sacraments, and radio',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Admin Actions
                _AdminActionCard(
                  icon: Icons.radio,
                  title: 'Church Radio Tracks',
                  subtitle: 'Manage radio music tracks',
                  color: kGold,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChurchRadioAdminPage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                
                _AdminActionCard(
                  icon: Icons.mic,
                  title: 'Church Radio Snippets',
                  subtitle: 'Manage radio message snippets',
                  color: kPurple,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChurchRadioSnippetsAdminPage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                
                _AdminActionCard(
                  icon: Icons.book,
                  title: 'Sermons',
                  subtitle: 'Manage sermon content',
                  color: kRed,
                  onTap: () {
                    // TODO: Navigate to sermons admin
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sermons admin coming soon')),
                    );
                  },
                ),
                const SizedBox(height: 12),
                
                _AdminActionCard(
                  icon: Icons.auto_stories,
                  title: 'Stories',
                  subtitle: 'Manage story content',
                  color: Colors.teal,
                  onTap: () {
                    // TODO: Navigate to stories admin
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Stories admin coming soon')),
                    );
                  },
                ),
                const SizedBox(height: 12),
                
                _AdminActionCard(
                  icon: Icons.local_fire_department,
                  title: 'Sacraments',
                  subtitle: 'Manage sacrament content',
                  color: Colors.orange,
                  onTap: () {
                    // TODO: Navigate to sacraments admin
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sacraments admin coming soon')),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _AdminActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.5)),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.lora(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: color.withValues(alpha: 0.7),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
