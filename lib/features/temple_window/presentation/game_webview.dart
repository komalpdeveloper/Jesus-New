import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
// Import for iOS-specific features.
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GameWebView extends StatefulWidget {
  const GameWebView({super.key});

  @override
  State<GameWebView> createState() => _GameWebViewState();
}

class _GameWebViewState extends State<GameWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();

    // Platform-specific params to enable media playback without user gesture on iOS
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(params);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            // Inject the UID when the page finishes loading
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              // Robust injection: checks main window, iframes, and retries for Unity loading
              final js = """
                (function() {
                  var uid = '${user.uid}';
                  function attemptInject() {
                    console.log('Attempting to set UID...');
                    if (typeof setUID === 'function') {
                      setUID(uid);
                      console.log('UID set in main window');
                      return true;
                    }
                    var frames = document.getElementsByTagName('iframe');
                    for (var i = 0; i < frames.length; i++) {
                      try {
                        if (frames[i].contentWindow && typeof frames[i].contentWindow.setUID === 'function') {
                          frames[i].contentWindow.setUID(uid);
                          console.log('UID set in iframe ' + i);
                          return true;
                        }
                      } catch (e) {
                        // Cross-origin restrictions might prevent access
                      }
                    }
                    return false;
                  }
                  
                  if (!attemptInject()) {
                    var attempts = 0;
                    var interval = setInterval(function() {
                      attempts++;
                      if (attemptInject() || attempts >= 20) {
                        clearInterval(interval);
                      }
                    }, 1000);
                  }
                })();
              """;

              controller.runJavaScript(js).catchError((e) {
                debugPrint('Error injecting JS: \$e');
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse('https://loomastudio.itch.io/jelly-jesus-v003'));

    _controller = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            // Simple back button overlay
            Positioned(
              top: 10,
              left: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
