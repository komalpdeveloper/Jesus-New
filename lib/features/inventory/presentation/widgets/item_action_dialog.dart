import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/inventory_item.dart';
import '../examine_page.dart';

class ItemActionDialog extends StatefulWidget {
  final InventoryItem item;
  final Function(int quantity)? onSacrifice;
  final Function(int quantity)? onSell;

  const ItemActionDialog({
    super.key,
    required this.item,
    this.onSacrifice,
    this.onSell,
  });

  @override
  State<ItemActionDialog> createState() => _ItemActionDialogState();
}

class _ItemActionDialogState extends State<ItemActionDialog> {
  late TextEditingController _quantityController;
  late int _selectedQuantity;

  @override
  void initState() {
    super.initState();
    _selectedQuantity = 1;
    _quantityController = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _updateQuantity(String value) {
    final parsed = int.tryParse(value);
    if (parsed != null && parsed > 0 && parsed <= widget.item.quantity) {
      setState(() => _selectedQuantity = parsed);
    } else if (parsed != null && parsed > widget.item.quantity) {
      setState(() {
        _selectedQuantity = widget.item.quantity;
        _quantityController.text = widget.item.quantity.toString();
        _quantityController.selection = TextSelection.fromPosition(
          TextPosition(offset: _quantityController.text.length),
        );
      });
    }
  }

  void _incrementQuantity() {
    if (_selectedQuantity < widget.item.quantity) {
      setState(() {
        _selectedQuantity++;
        _quantityController.text = _selectedQuantity.toString();
      });
    }
  }

  void _decrementQuantity() {
    if (_selectedQuantity > 1) {
      setState(() {
        _selectedQuantity--;
        _quantityController.text = _selectedQuantity.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1410),
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // Treasury logo
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Image.asset(
                'assets/inventory/inventory_header.png',
                height: 30,
                fit: BoxFit.contain,
              ),
            ),
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              child: ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [
                    const Color(0xFFFFD700),
                    const Color(0xFFD4AF37),
                    const Color(0xFFFFD700),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ).createShader(bounds),
                child: Text(
                  widget.item.name,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.tangerine(
                    fontSize: 36,
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
            ),
            // Value with ring image
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/icon/ring_img.png',
                    width: 20,
                    height: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.item.value}',
                    style: GoogleFonts.cinzel(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFD4AF37),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Available quantity
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Available: ${widget.item.quantity}',
                style: GoogleFonts.lato(
                  fontSize: 14,
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.7),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Quantity input with +/- buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Text(
                    'Enter Quantity',
                    style: GoogleFonts.cinzel(
                      fontSize: 14,
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildQuantityButton(
                        icon: Icons.remove,
                        onTap: _decrementQuantity,
                        enabled: _selectedQuantity > 1,
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 100,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2416),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFD4AF37),
                            width: 2,
                          ),
                        ),
                        child: TextField(
                          controller: _quantityController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cinzel(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFD4AF37),
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          onChanged: _updateQuantity,
                        ),
                      ),
                      const SizedBox(width: 16),
                      _buildQuantityButton(
                        icon: Icons.add,
                        onTap: _incrementQuantity,
                        enabled: _selectedQuantity < widget.item.quantity,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildActionButton(
                    context,
                    'Sacrifice',
                    Icons.local_fire_department,
                    () {
                      if (widget.onSacrifice != null) {
                        widget.onSacrifice!(_selectedQuantity);
                      }
                    },
                    isPrimary: true,
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(context, 'Examine', Icons.search, () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ExaminePage(item: widget.item),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    context,
                    'Pray Over',
                    Icons.auto_awesome,
                    () {
                      Navigator.pop(context);
                      _showMessage(
                        context,
                        'Praying over ${widget.item.name}...',
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(context, 'Sell', Icons.sell, () {
                    if (widget.onSell != null) {
                      widget.onSell!(_selectedQuantity);
                    }
                  }),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Close button
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
                style: GoogleFonts.lato(
                  fontSize: 14,
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildQuantityButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF2C2416),
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled
                ? const Color(0xFFD4AF37)
                : const Color(0xFFD4AF37).withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Icon(
          icon,
          color: enabled
              ? const Color(0xFFD4AF37)
              : const Color(0xFFD4AF37).withValues(alpha: 0.3),
          size: 20,
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool isPrimary = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isPrimary
              ? const Color(0xFFD4AF37).withValues(alpha: 0.2)
              : const Color(0xFF2C2416),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFFD4AF37),
            width: isPrimary ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(
                0xFFD4AF37,
              ).withValues(alpha: isPrimary ? 0.4 : 0.2),
              blurRadius: isPrimary ? 10 : 6,
              spreadRadius: isPrimary ? 2 : 1,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFFD4AF37), size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.cinzel(
                fontSize: 16,
                fontWeight: isPrimary ? FontWeight.bold : FontWeight.w600,
                color: const Color(0xFFD4AF37),
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.lato(color: const Color(0xFFD4AF37)),
          textAlign: TextAlign.center,
        ),
        backgroundColor: const Color(0xFF2C2416),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFFD4AF37), width: 1),
        ),
      ),
    );
  }
}
