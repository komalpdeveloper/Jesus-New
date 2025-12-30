import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:clientapp/core/theme/palette.dart';
// Removed navigation to ShopPage; promo cards are now non-interactive

class PromoItem {
  final String title;
  final String subtitle;
  final String? imageAsset; // optional background image
  const PromoItem({required this.title, required this.subtitle, this.imageAsset});
}

class PromoBanners extends StatefulWidget {
  final List<PromoItem>? items;
  final bool compact; // smaller height for shop page
  final EdgeInsetsGeometry? margin;

  const PromoBanners({super.key, this.items, this.compact = false, this.margin});

  @override
  State<PromoBanners> createState() => _PromoBannersState();
}

class _PromoBannersState extends State<PromoBanners> {
  late final PageController _controller;
  int _index = 0;
  Timer? _timer;

  List<PromoItem> get _items => widget.items ?? const [
        PromoItem(
          title: 'Weekend Clearance',
          subtitle: 'Up to 40% off select relics. Today only.',
          imageAsset: 'assets/banner/banner.png',
        ),
        PromoItem(
          title: 'Double Rings',
          subtitle: 'Earn 2x rings on bundles all week.',
        ),
        PromoItem(
          title: 'New Arrivals',
          subtitle: 'Freshly anointed items just landed.',
        ),
      ];

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.9);
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_controller.hasClients || _items.isEmpty) return;
      final next = (_index + 1) % _items.length;
      _controller.animateToPage(next, duration: const Duration(milliseconds: 450), curve: Curves.easeOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.compact ? 120.0 : 150.0;
    final items = _items;
    return Padding(
      padding: widget.margin ?? const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: h,
            child: PageView.builder(
              controller: _controller,
              itemCount: items.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => _PromoCard(item: items[i]),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(items.length, (i) {
              final active = i == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 14 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: active ? kGold : kGold.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            }),
          )
        ],
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  final PromoItem item;
  const _PromoCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: null, // disabled: no action on tap
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1F170C),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kGold.withValues(alpha: 0.45), width: 1.2),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 6))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (item.imageAsset != null)
                  Image.asset(item.imageAsset!, fit: BoxFit.cover),
                // overlay gradient
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xAA2B0E47), Color(0x9910091F)],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(item.title, style: GoogleFonts.cinzel(color: kGold, fontWeight: FontWeight.w800, fontSize: 18)),
                      const SizedBox(height: 8),
                      Text(item.subtitle, style: GoogleFonts.lora(color: Colors.white70, fontSize: 13, height: 1.3)),
                      // const SizedBox(height: 12),
                      // ElevatedButton(
                      //   style: ElevatedButton.styleFrom(
                      //     backgroundColor: kGold,
                      //     foregroundColor: Colors.black,
                      //     padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      //   ),
                      //   onPressed: () {
                      //     Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopPage()));
                      //   },
                      //   child: Text('Shop Now', style: GoogleFonts.cinzel(fontWeight: FontWeight.w700)),
                      // ),
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
