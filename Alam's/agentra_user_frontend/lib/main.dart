import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme/app_theme.dart';
import 'models/package.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/packages/package_detail_screen.dart';
import 'screens/packages/saved_packages_screen.dart';
import 'screens/search/search_screen.dart';
import 'screens/search/search_results_screen.dart';
import 'screens/bookings/bookings_screen.dart';
import 'screens/bookings/booking_confirmation_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/profile/enter_details_screen.dart';
import 'screens/payments/payment_screen.dart';
import 'screens/payments/payment_success_screen.dart';
import 'screens/payments/payment_history_screen.dart';
import 'screens/reviews/reviews_screen.dart';
import 'screens/reviews/rate_trip_screen.dart';
import 'screens/favorites/favorites_screen.dart';
import 'screens/support/support_chat_screen.dart';
import 'screens/complaints/complaint_screen.dart';
import 'screens/complaints/file_complaint_screen.dart';
import 'screens/refunds/refund_request_screen.dart';
import 'screens/refunds/refund_success_screen.dart';
import 'screens/chatbot/chatbot_screen.dart';
import 'screens/reviews/write_review_screen.dart';
import 'screens/bookings/create_booking_screen.dart';
import 'screens/promotions/promotions_screen.dart';

void main() {
  runApp(const AgentraApp());
}

class AgentraApp extends StatelessWidget {
  const AgentraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agentra Travel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          secondary: AppColors.orange,
          surface: AppColors.background,
          error: AppColors.error,
        ),
        scaffoldBackgroundColor: AppColors.background,
        textTheme: GoogleFonts.interTextTheme(),
        fontFamily: GoogleFonts.inter().fontFamily,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.textPrimary),
          titleTextStyle: AppTextStyles.headingSmall,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/signup': (context) => const SignupScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/search': (context) => const SearchScreen(),
        '/search-results': (context) => const SearchResultsScreen(),
        '/bookings': (context) => const BookingsScreen(),
        '/booking-confirmation': (context) => const BookingConfirmationScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/edit-profile': (context) => const EditProfileScreen(),
        '/enter-details': (context) => const EnterDetailsScreen(),
        '/saved-packages': (context) => const SavedPackagesScreen(),
        '/payment': (context) => const PaymentScreen(),
        '/payment-success': (context) => const PaymentSuccessScreen(),
        '/payment-history': (context) => const PaymentHistoryScreen(),
        '/reviews': (context) => const ReviewsScreen(),
        '/favorites': (context) => const FavoritesScreen(),
        '/support-chat': (context) => const SupportChatScreen(),
        '/complaint': (context) => const ComplaintsScreen(),
        '/file-complaint': (context) => const FileComplaintScreen(),
        '/refund-request': (context) => const RefundRequestScreen(),
        '/refund-success': (context) => const RefundSuccessScreen(),
        '/chat': (context) => const ChatbotScreen(),
        '/promotions': (context) => const PromotionsScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/package-detail') {
          final packageId = settings.arguments as String?;
          return MaterialPageRoute(
            builder: (context) => PackageDetailScreen(
              packageId: packageId ?? '',
            ),
          );
        }
        if (settings.name == '/booking-form') {
          final package = settings.arguments as Package?;
          if (package == null) {
            return MaterialPageRoute(
              builder: (context) => Scaffold(
                appBar: AppBar(title: const Text('Error')),
                body: const Center(
                  child: Text('Package information is required'),
                ),
              ),
            );
          }
          return MaterialPageRoute(
            builder: (context) => CreateBookingScreen(package: package),
          );
        }
        if (settings.name == '/write-review') {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (context) => WriteReviewScreen(
              packageId: args?['packageId'] ?? '',
              packageTitle: args?['packageTitle'] ?? 'Package',
            ),
          );
        }
        if (settings.name == '/rate-trip') {
          final packageId = settings.arguments as String?;
          return MaterialPageRoute(
            builder: (context) => RateTripScreen(
              packageId: packageId ?? '',
            ),
          );
        }
        return null;
      },
    );
  }
}

class bookingdetailscreen {
  const bookingdetailscreen();
}