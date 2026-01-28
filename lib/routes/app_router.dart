import 'package:fin_pay/screens/auth/create_account_screen.dart';
import 'package:fin_pay/screens/auth/fingerprint_setup_screen.dart';
import 'package:fin_pay/screens/auth/forgot_password_screen.dart';
import 'package:fin_pay/screens/auth/login_screen.dart';
import 'package:fin_pay/screens/auth/verification_screen.dart';
import 'package:fin_pay/screens/cards/add_card_screen.dart';
import 'package:fin_pay/screens/cards/my_cards_screen.dart';
import 'package:fin_pay/screens/home/home_screen.dart';
import 'package:fin_pay/screens/notifications/notifications_screen.dart';
import 'package:fin_pay/screens/onboarding/onboarding_screen.dart';
import 'package:fin_pay/screens/onboarding/welcome_screen.dart';
import 'package:fin_pay/screens/profile/profile_screen.dart';
import 'package:fin_pay/screens/statistics/statistics_screen.dart';
import 'package:fin_pay/screens/transactions/transactions_screen.dart';
import 'package:fin_pay/screens/transfer/transfer_review_screen.dart';
import 'package:fin_pay/screens/transfer/transfer_screen.dart';
import 'package:fin_pay/screens/transfer/transfer_success_screen.dart';
import 'package:fin_pay/widgets/animations/cred_page_transition.dart';
import 'package:flutter/material.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const WelcomeScreen());
      case '/onboarding':
        return CredPageTransition(page: const OnboardingScreen());
      case '/login':
        return CredPageTransition(page: const LoginScreen());
      case '/create-account':
        return CredPageTransition(page: const CreateAccountScreen());
      case '/verification':
        return CredPageTransition(page: const VerificationScreen());
      case '/fingerprint-setup':
        return CredPageTransition(page: const FingerprintSetupScreen());
      case '/forgot-password':
        return CredPageTransition(page: const ForgotPasswordScreen());
      case '/home':
        return CredPageTransition(page: const HomeScreen());
      case '/transactions':
        return CredPageTransition(page: const TransactionsScreen());
      case '/transfer':
        return CredPageTransition(page: const TransferScreen());
      case '/transfer-review':
        final args = settings.arguments as Map<String, dynamic>?;
        return CredPageTransition(
          page: TransferReviewScreen(
            recipientName: args?['recipientName'] ?? 'Kelvin Habit',
            recipientAccount: args?['recipientAccount'] ?? '**** 5961',
            amount: args?['amount'] ?? '420.90',
          ),
        );
      case '/transfer-success':
        final args = settings.arguments as Map<String, dynamic>?;
        return CredPageTransition(
          page: TransferSuccessScreen(
            recipientName: args?['recipientName'] ?? 'Kelvin Habit',
            amount: args?['amount'] ?? '420.90',
          ),
        );
      case '/cards':
        return CredPageTransition(page: const MyCardsScreen());
      case '/add-card':
        return CredPageTransition(page: const AddCardScreen());
      case '/profile':
        return CredPageTransition(page: const ProfileScreen());
      case '/statistics':
        return CredPageTransition(page: const StatisticsScreen());
      case '/notifications':
        return CredPageTransition(page: const NotificationsScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }
}
