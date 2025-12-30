import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:clientapp/shared/widgets/back_nav_button.dart';
import '../models/inventory_item.dart';
import 'package:flutter/foundation.dart';

class ExaminePage extends StatelessWidget {
  final InventoryItem item;

  const ExaminePage({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    debugPrint('[ExaminePage] Item: ${item.name}, ImageURL: ${item.imageUrl}');
    
    return Scaffold(
      backgroundColor: const Color(0xFF1A1410),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: const Padding(
          padding: EdgeInsets.only(left: 6),
          child: BackNavButton(),
        ),
        title: Image.asset(
          'assets/inventory/inventory_header.png',
          height: 40,
          fit: BoxFit.contain,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Item name with glow effect
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [
                      const Color(0xFFFFD700),
                      const Color(0xFFD4AF37),
                      const Color(0xFFFFD700),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ).createShader(bounds),
                  child: Text(
                    item.name,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.tangerine(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                      shadows: [
                        Shadow(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.9),
                          blurRadius: 12,
                        ),
                        Shadow(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.6),
                          blurRadius: 24,
                        ),
                        Shadow(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                          blurRadius: 36,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                
                // Product image
                Container(
                  width: double.infinity,
                  height: 300,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2416),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD4AF37), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: item.imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: item.imageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFD4AF37),
                              ),
                            ),
                            errorWidget: (context, url, error) => Center(
                              child: Icon(
                                Icons.image_not_supported,
                                size: 80,
                                color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                              ),
                            ),
                          )
                        : Center(
                            child: Icon(
                              Icons.image_not_supported,
                              size: 80,
                              color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 30),
                
                // Value with ring image
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Value:',
                      style: GoogleFonts.cinzel(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Image.asset(
                      'assets/icon/ring_img.png',
                      width: 24,
                      height: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${item.value}',
                      style: GoogleFonts.cinzel(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFD4AF37),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Quantity
                Text(
                  'Quantity: ${item.quantity}',
                  style: GoogleFonts.cinzel(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 30),
                
                // Description section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2416).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD4AF37), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Description',
                        style: GoogleFonts.cinzel(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFD4AF37),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        item.description.isNotEmpty
                            ? item.description
                            : 'No description available.',
                        style: GoogleFonts.lato(
                          fontSize: 16,
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.9),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
