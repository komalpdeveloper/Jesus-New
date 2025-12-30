import 'package:clientapp/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:clientapp/features/chat/presentation/pages/chat_screen.dart';
import 'package:clientapp/features/profile/presentation/pages/profile_screen.dart';
import 'package:clientapp/features/prayer/presentation/pages/prayer_mode.dart';
import 'package:clientapp/core/services/notifications.dart';
import 'package:clientapp/core/theme/palette.dart';
import 'package:clientapp/shared/widgets/cosmic_background.dart';
import 'package:clientapp/features/store_admin/data/admin_auth.dart';
import 'package:clientapp/features/store_admin/presentation/admin_pages.dart';
import 'package:clientapp/core/navigation/route_observer.dart';
import 'package:clientapp/core/auth/auth_state_manager.dart';
import 'package:clientapp/features/auth/presentation/login_screen.dart';
import 'package:clientapp/features/auth/presentation/username_screen.dart';
import 'package:clientapp/features/auth/presentation/gender_screen.dart';
import 'package:clientapp/features/auth/services/user_profile_service.dart';
import 'package:clientapp/features/auth/models/user_profile.dart'; // Import the model
import 'package:clientapp/core/services/user_service.dart';
import 'package:clientapp/features/temple_window/presentation/temple_window_page.dart';
import 'package:clientapp/features/church/presentation/church_page.dart';
import 'package:clientapp/features/inventory/presentation/inventory_screen.dart';
import 'package:clientapp/shared/widgets/heaven_glow.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:clientapp/features/pressure_demo/pressure_demo_screen.dart';
import 'package:clientapp/shared/widgets/animated_loading_indicator.dart';
import 'package:clientapp/core/services/global_radio_service.dart';
import 'package:clientapp/shared/widgets/floating_radio_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:clientapp/core/reward/daily/daily_reward_service.dart';
import 'package:clientapp/shared/widgets/electric_reward_overlay.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Initialize background audio service
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
  );

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize global radio service after Firebase
  await GlobalRadioService.instance.initialize();

  // Note: Firebase Auth persistence is automatic on iOS/Android
  // setPersistence() is only for web platforms
  // On mobile, auth state is automatically persisted in secure storage

  // Verify Firebase at runtime
  try {
    final app = Firebase.apps.first;
    debugPrint('[Firebase] Initialized app: ${app.name}');
    debugPrint('[Firebase] Project ID: ${app.options.projectId}');
    debugPrint('[Firebase] App ID: ${app.options.appId}');
    debugPrint(
      '[Firebase] Messaging Sender ID: ${app.options.messagingSenderId}',
    );

    // Check if user is already signed in
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      debugPrint('[Firebase] User already signed in: ${currentUser.uid}');
      debugPrint('[Firebase] Email: ${currentUser.email}');
      debugPrint(
        '[Firebase] Provider: ${currentUser.providerData.map((p) => p.providerId).join(", ")}',
      );
    } else {
      debugPrint('[Firebase] No user currently signed in');
    }
  } catch (e) {
    debugPrint('[Firebase] Initialization check failed: $e');
  }

  // Initialize RevenueCat
  await Purchases.setLogLevel(LogLevel.debug);
  if (Platform.isIOS) {
    PurchasesConfiguration configuration = PurchasesConfiguration(
      "appl_xALWmgHJlVZPJpKqcpEbYSYVTBi",
    );
    await Purchases.configure(configuration);
  }

  runApp(const JesusNewApp());
  //   final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  //   FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  // await Firebase.initializeApp(
  //     options: DefaultFirebaseOptions.currentPlatform,
  // );
  //   runApp(const JesusNewApp());

  // Remove splash after first frame and async init to prevent a blank gap
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await NotificationsHelper.init();
    FlutterNativeSplash.remove();
  });
}

class JesusNewApp extends StatefulWidget {
  const JesusNewApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  State<JesusNewApp> createState() => _JesusNewAppState();
}

class _JesusNewAppState extends State<JesusNewApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Clear chat messages when app is detached (closed)
    if (state == AppLifecycleState.detached) {
      _clearChatMessages();
    }
  }

  Future<void> _clearChatMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('chat_messages_')) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      debugPrint('Error clearing chat messages: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseText = GoogleFonts.loraTextTheme();
    return MaterialApp(
      navigatorKey: JesusNewApp.navigatorKey,
      debugShowCheckedModeBanner: false,
      navigatorObservers: [routeObserver],
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: kDeepBlack,
        colorScheme: const ColorScheme.dark(
          primary: kPurple,
          secondary: kGold,
          surface: kRoyalBlue,
          onSurface: Colors.white,
          onPrimary: Colors.black,
          onSecondary: Colors.black,
        ),
        textTheme: baseText.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: kRoyalBlue,
          contentTextStyle: TextStyle(color: Colors.white),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      routes: {
        '/temple-window': (_) => const TempleWindowPage(),
        '/church': (_) => const ChurchPage(),
        '/inventory': (_) => const InventoryScreen(),
        '/pressure-demo': (_) => const PressureDemoScreen(),
      },
      builder: (context, child) {
        // Add floating radio button to all screens
        // Use separate widgets to prevent radio button rebuilds from affecting child
        return _AppWithFloatingRadio(child: child);
      },
      // Show login until a Firebase user is available; then show the app
      home: AuthStateManager(
        builder: (context, user, isLoading) {
          if (isLoading) {
            return const LoadingHomeScreen(
              message: 'Loading...',
              accent: kPurple,
            );
          }

          if (user != null) {
            // Check if profile is complete
            return ProfileCheckWidget(user: user);
          }

          return const LoginScreen();
        },
      ),
    );
  }
}

class MainNav extends StatefulWidget {
  const MainNav({super.key});
  @override
  State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const ChatScreen(
        title: "Living Jesus",
        accent: kPurple,
        endpoint: "/chat/jesus",
        backgroundImage: "assets/common/jesus.png",
      ),
      const ChatScreen(
        title: "Living Word",
        accent: kRed,
        endpoint: "/chat/word",
        backgroundImage: "assets/common/word.png",
      ),
      const ChatScreen(
        title: "Living God",
        accent: kGold,
        endpoint: "/chat/god",
        backgroundImage: "assets/common/god.png",
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDeepBlack,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: false,
          flexibleSpace: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left: Profile Button
                Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: _glassButton(
                        tooltip: 'Profile',
                        icon: Icons.person_rounded,
                        iconColor: Colors.white,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProfileScreen(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Center: Ring animation (75x75) -> tap opens Store Shell
                GestureDetector(
                  onTap: () async {
                    // 1. Dismiss keyboard to prevent layout resizing jank during transition
                    FocusScope.of(context).unfocus();

                    // 2. Wait for keyboard close animation (approx 300ms on most devices)
                    // This ensures the previous screen is stable before we start the fade
                    await Future.delayed(const Duration(milliseconds: 300));

                    if (!context.mounted) return;

                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            const TempleWindowPage(),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                        transitionDuration: const Duration(milliseconds: 500),
                        reverseTransitionDuration: const Duration(
                          milliseconds: 500,
                        ),
                      ),
                    );
                  },
                  onLongPress: () async {
                    // Secret long press to open Admin
                    final loggedIn = await AdminAuth.isLoggedIn();
                    if (!context.mounted) return;
                    if (loggedIn) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminHomePage(store: adminStore),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminLoginPage(),
                        ),
                      );
                    }
                  },
                  child: SizedBox(
                    height: 75,
                    width: 75,
                    child: Tooltip(
                      message: 'Open Wordmart Store',
                      child: Image.asset(
                        'assets/ring/ring.gif',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                // Right: Prayer Mode button
                Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: _glassButton(
                        tooltip: 'Prayer Mode',
                        icon: Icons.volunteer_activism,
                        iconColor: kGold,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PrayerMode()),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: CosmicBackground(
        accent: _currentIndex == 0
            ? kPurple
            : _currentIndex == 1
            ? kRed
            : kGold,
        child: IndexedStack(index: _currentIndex, children: _screens),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color.fromARGB(255, 14, 20, 44), //findsd
          border: Border(top: BorderSide(color: kRoyalBlue, width: 1)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  imagePath: 'assets/buttons/jesus.png',
                  label: 'Jesus',
                  color: kPurple,
                ),
                _buildNavItem(
                  index: 1,
                  imagePath: 'assets/buttons/word.png',
                  label: 'Word',
                  color: kRed,
                ),
                _buildNavItem(
                  index: 2,
                  imagePath: 'assets/buttons/god.png',
                  label: 'God',
                  color: kGold,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String imagePath,
    required String label,
    required Color color,
  }) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.6 : 1,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              child: HeavenGlow(
                color: color,
                isSelected: isSelected,
                child: Image.asset(
                  imagePath,
                  height: 50,
                  width: 50,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // const SizedBox(height: 4),
            //  isSelected?SizedBox() :     Text(
            //         label,
            //         style: TextStyle(
            //           fontSize: 11,
            //           color: isSelected ? color : Colors.white70,
            //           fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            //         ),
            //       ),
          ],
        ),
      ),
    );
  }

  Widget _glassButton({
    required String tooltip,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: kRoyalBlue.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kRoyalBlue.withValues(alpha: 0.8)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 10,
            spreadRadius: 2,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(icon, size: 20, color: iconColor),
          ),
        ),
      ),
    );
  }
}

// Widget to check profile completion and route accordingly
class ProfileCheckWidget extends StatefulWidget {
  final User user;

  const ProfileCheckWidget({super.key, required this.user});

  @override
  State<ProfileCheckWidget> createState() => _ProfileCheckWidgetState();
}

class _ProfileCheckWidgetState extends State<ProfileCheckWidget>
    with RouteAware {
  // Cache the future to prevent unnecessary re-fetching on rebuilds
  late Future<UserProfile?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    _profileFuture = UserProfileService.instance.getUserProfile(
      widget.user.uid,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route changes to refresh when coming back
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // Called when returning to this route - refresh the profile check
    setState(() {
      _loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingHomeScreen(
            message: 'Perfecting profile...',
            accent: kPurple,
          );
        }

        final profile = snapshot.data;

        // If profile doesn't exist or is incomplete, continue onboarding
        if (profile == null || !profile.isProfileComplete) {
          // Check which step to show based on what's missing
          if (profile?.username == null) {
            return const UsernameScreen();
          } else {
            return const GenderScreen();
          }
        }

        // Ensure user doc exists with default ringCount
        Future.microtask(() async {
          await UserService.instance.ensureUserInitialized();
          // Check for daily login reward
          final claimed = await DailyRewardService.instance.checkDailyReward();
          if (claimed && context.mounted) {
            ElectricRewardOverlay.show(context);
          }
        });
        return const MainNav();
      },
    );
  }
}

// Loading screen that matches home design: background image + overlay + indicator
class LoadingHomeScreen extends StatelessWidget {
  final String message;
  final Color accent;
  const LoadingHomeScreen({
    super.key,
    this.message = 'Loading...',
    this.accent = kPurple,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/loading/loadingbg.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          // subtle dark overlay to ensure indicator and text are readable
          Container(color: Colors.black.withOpacity(0.7)),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedLoadingIndicator(color: accent, size: 120),
                const SizedBox(height: 32),
                Text(
                  message,
                  style: GoogleFonts.lora(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Isolated widget wrapper to prevent FloatingRadioButton rebuilds from affecting app content
class _AppWithFloatingRadio extends StatelessWidget {
  final Widget? child;

  const _AppWithFloatingRadio({this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main app content - won't rebuild when radio button updates
        child ?? const SizedBox.shrink(),
        // Floating radio button in its own isolated layer
        const FloatingRadioButton(),
      ],
    );
  }
}
