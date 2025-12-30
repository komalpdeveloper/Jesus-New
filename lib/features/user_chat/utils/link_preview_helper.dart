import 'package:any_link_preview/any_link_preview.dart';
import '../models/user_chat_message.dart';

class LinkPreviewHelper {
  /// Extracts the first URL from text
  static String? extractUrl(String text) {
    final urlPattern = RegExp(
      r'https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
      caseSensitive: false,
    );
    
    final match = urlPattern.firstMatch(text);
    return match?.group(0);
  }

  /// Fetches link preview metadata
  static Future<LinkPreview?> fetchLinkPreview(String url) async {
    try {
      // Validate URL
      if (!AnyLinkPreview.isValidLink(url)) {
        return null;
      }

      // Fetch metadata
      final metadata = await AnyLinkPreview.getMetadata(
        link: url,
        cache: const Duration(hours: 24),
      );

      if (metadata == null) {
        return null;
      }

      return LinkPreview(
        url: url,
        title: metadata.title,
        description: metadata.desc,
        imageUrl: metadata.image,
      );
    } catch (e) {
      // Error fetching link preview, return null
      return null;
    }
  }

  /// Checks if text contains a URL
  static bool containsUrl(String text) {
    return extractUrl(text) != null;
  }
}
