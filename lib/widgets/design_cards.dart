import 'package:flutter/material.dart';
import '../models/user_design.dart';
import '../utils/image_resolver.dart';
import 'translated_text.dart';

class DraftCard extends StatefulWidget {
  final UserDesign design;
  final VoidCallback onTap;
  final bool showActions;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const DraftCard({
    Key? key,
    required this.design,
    required this.onTap,
    this.showActions = false,
    this.onEdit,
    this.onDelete,
  }) : super(key: key);

  @override
  State<DraftCard> createState() => _DraftCardState();
}

class _DraftCardState extends State<DraftCard> {
  bool _isMenuOpen = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
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
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                    child: isNetworkImage(widget.design.template.thumbnail)
                        ? Image.network(resolveImageUrl(widget.design.template.thumbnail), fit: BoxFit.cover)
                        : Image.asset(cleanAssetPath(widget.design.template.thumbnail), fit: BoxFit.cover),
                  ),
                  if (widget.showActions)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: _isMenuOpen ? _buildExpandedMenu() : _buildMenuButton(),
                    ),
                ],
              ),
            ),
            Container(
              height: 36,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TranslatedText(
                widget.design.template.title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isMenuOpen = true;
        });
      },
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.more_horiz, size: 16, color: Colors.black87),
      ),
    );
  }

  Widget _buildExpandedMenu() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildIconButton(Icons.edit_outlined, () {
          setState(() => _isMenuOpen = false);
          if (widget.onEdit != null) widget.onEdit!();
        }),
        const SizedBox(height: 8),
        _buildIconButton(Icons.delete_outline, () {
          setState(() => _isMenuOpen = false);
          if (widget.onDelete != null) widget.onDelete!();
        }),
        const SizedBox(height: 8),
        _buildIconButton(Icons.close, () {
          setState(() {
            _isMenuOpen = false;
          });
        }),
      ],
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 16, color: Colors.black87),
      ),
    );
  }
}

class CompletedDesignCard extends StatefulWidget {
  final UserDesign design;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final VoidCallback onTap;

  const CompletedDesignCard({
    Key? key,
    required this.design,
    required this.onDelete,
    required this.onShare,
    required this.onTap,
  }) : super(key: key);

  @override
  State<CompletedDesignCard> createState() => _CompletedDesignCardState();
}

class _CompletedDesignCardState extends State<CompletedDesignCard> {
  bool _isMenuOpen = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFDF0F1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: isNetworkImage(widget.design.template.thumbnail)
                        ? Image.network(resolveImageUrl(widget.design.template.thumbnail), fit: BoxFit.cover)
                        : Image.asset(cleanAssetPath(widget.design.template.thumbnail), fit: BoxFit.cover),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: _isMenuOpen ? _buildExpandedMenu() : _buildMenuButton(),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TranslatedText(
          widget.design.template.title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildMenuButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isMenuOpen = true;
        });
      },
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.more_horiz, size: 16, color: Colors.black87),
      ),
    );
  }

  Widget _buildExpandedMenu() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildIconButton(Icons.share, () {
          setState(() => _isMenuOpen = false);
          widget.onShare();
        }),
        const SizedBox(height: 8),
        _buildIconButton(Icons.delete_outline, () {
          setState(() => _isMenuOpen = false);
          widget.onDelete();
        }),
        const SizedBox(height: 8),
        _buildIconButton(Icons.close, () {
          setState(() {
            _isMenuOpen = false;
          });
        }),
      ],
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 16, color: Colors.black87),
      ),
    );
  }
}
