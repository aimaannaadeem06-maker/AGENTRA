import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/dashboard_with_packages_screen.dart';
import 'screens/create_package_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/owner_login_screen.dart';
import 'screens/owner_dashboard_screen.dart';
import 'screens/package_performance_screen.dart';
import 'screens/payment_history_screen.dart';
import 'screens/agent_profile_screen.dart';
import 'screens/edit_agent_profile_screen.dart';
import 'screens/refund_requests_screen.dart';
import 'screens/bookings_screen.dart';
import 'screens/subscription_screen.dart';
import 'screens/premium_payment_screen.dart';
import 'screens/complaint_screen.dart';
import 'screens/owner_agent_verification_screen.dart';
import 'screens/owner_manage_accounts_screen.dart';
import 'screens/owner_complaints_screen.dart';
import 'screens/owner_financial_screen.dart';
import 'screens/agent_complaints_screen.dart';
import 'screens/saved_packages_screen.dart';
import 'screens/search_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AgentraAgentPortal());
}

class AgentraAgentPortal extends StatelessWidget {
  const AgentraAgentPortal({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agentra - Agent Portal',
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
        textTheme: ThemeData.light().textTheme,
        fontFamily: const TextStyle().fontFamily,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/dashboard': (context) => const DashboardWithPackagesScreen(),
        '/dashboard-packages': (context) => const DashboardWithPackagesScreen(),
        '/create-package': (context) => const CreatePackageScreen(),
        '/edit-package': (context) => const CreatePackageScreen(),
        '/owner-login': (context) => const OwnerLoginScreen(),
        '/owner-dashboard': (context) => const OwnerDashboardScreen(),
        '/performance': (context) => const PackagePerformanceScreen(),
        '/payment-history': (context) => const PaymentHistoryScreen(),
        '/profile': (context) => const AgentProfileScreen(),
        '/edit-profile': (context) => const EditAgentProfileScreen(),

        '/refund-requests': (context) => const RefundRequestsScreen(),
        '/bookings': (context) => const BookingsScreen(),
        '/subscription': (context) => const SubscriptionScreen(),
        '/premium-payment': (context) => const PremiumPaymentScreen(),
        '/complaint': (context) => const ComplaintScreen(),
        '/saved-packages': (context) => const SavedPackagesScreen(),
        '/search': (context) => const SearchScreen(),
        // Owner routes
        '/owner-agent-verification': (context) => const OwnerAgentVerificationScreen(),
        '/owner-manage-accounts': (context) => const OwnerManageAccountsScreen(),
        '/owner-complaints': (context) => const OwnerComplaintsScreen(),
        '/owner-financial': (context) => const OwnerFinancialScreen(),
        '/agent-complaints': (context) => const AgentComplaintsScreen(),
      },
      onGenerateRoute: (settings) {
        return null;
      },
    );
  }
}
