import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_chat_message.dart';
import '../../../core/theme/palette.dart';

class LinkPreviewCard extends StatelessWidget {
  final LinkPreview linkPreview;
  final bool isMe;

  const LinkPreviewCard({
    super.key,
    required this.linkPreview,
    required this.isMe,
  });

  Future<void> _launchUrl() async {
    final uri = Uri.parse(linkPreview.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _launchUrl,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isMe 
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.2),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (linkPreview.imageUrl != null && linkPreview.imageUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: linkPreview.imageUrl!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 160,
                  color: Colors.white.withValues(alpha: 0.05),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: kPurple,
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 160,
                  color: Colors.white.withValues(alpha: 0.05),
                  child: const Center(
                    child: Icon(
                      Icons.link,
                      color: Colors.white54,
                      size: 40,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (linkPreview.title != null && linkPreview.title!.isNotEmpty)
                    Text(
                      linkPreview.title!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (linkPreview.description != null && linkPreview.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      linkPreview.description!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.link,
                        size: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _getDomain(linkPreview.url),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (e) {
      return url;
    }
  }
}
