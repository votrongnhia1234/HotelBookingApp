import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;

import 'firebase_options.dart';
import 'package:stayeasy/screens/booking_screen.dart';
import 'package:stayeasy/screens/booking_success_screen.dart';
import 'package:stayeasy/screens/home_screen.dart';
import 'package:stayeasy/screens/hotel_detail_screen.dart';
import 'package:stayeasy/screens/login_phone_screen.dart';
import 'package:stayeasy/screens/my_trips_screen.dart';
import 'package:stayeasy/screens/payment_screen.dart';
import 'package:stayeasy/screens/profile_screen.dart';
import 'package:stayeasy/screens/review_screen.dart';
import 'package:stayeasy/screens/splash_screen.dart';
import 'package:stayeasy/screens/voucher_screen.dart';
import 'package:stayeasy/screens/admin_dashboard_screen.dart';
import 'package:stayeasy/screens/partner_dashboard_screen.dart';
import 'package:stayeasy/screens/personal_info_screen.dart';
import 'package:stayeasy/screens/room_management_screen.dart';
import 'package:stayeasy/screens/transaction_history_screen.dart';
import 'package:stayeasy/screens/favorites_screen.dart';
import 'package:stayeasy/state/auth_state.dart';
import 'package:stayeasy/screens/hotel_image_management_screen.dart';
import 'package:stayeasy/models/booking.dart';
import 'package:stayeasy/models/hotel.dart';
import 'package:stayeasy/models/room.dart';
import 'config/stripe_config.dart';
import 'config/theme.dart';
import 'package:stayeasy/screens/partner_bookings_screen.dart';
import 'package:stayeasy/screens/payment_methods_screen.dart';
import 'package:stayeasy/screens/notifications_screen.dart';

const kBrandBlue = Color(0xFF1E88E5);
const kRadius = 16.0;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    stripe.Stripe.publishableKey = StripeConfig.publishableKey;
    await stripe.Stripe.instance.applySettings();
  } catch (_) {
    // Skip Stripe init when not supported or not configured.
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AuthState.I.loadFromStorage();
  // If you want to restore session from a previously-signed-in Firebase user,
  // call AuthService().restoreSessionIfNeeded() from a top-level widget (for
  // example, inside the SplashScreen) after Firebase initialization.
  runApp(const StayEasyApp());
}

class StayEasyApp extends StatelessWidget {
  const StayEasyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData();

    return MaterialApp(
      title: 'StayEasy',
      debugShowCheckedModeBanner: false,
      initialRoute: '/splash',
      theme: AppTheme.buildTheme(base),
      routes: {
        '/splash': (_) => const SplashScreen(),
        '/home': (_) => const HomeScreen(),
        '/login': (_) => const LoginPhoneScreen(),
        '/trips': (_) => const MyTripsScreen(),
        '/profile': (_) => const ProfileScreen(),
        '/profile/payment-methods': (_) => const PaymentMethodsScreen(),
        '/profile/notifications': (_) => const NotificationsSettingsScreen(),
        '/voucher': (_) => const VoucherScreen(),
        '/admin-dashboard': (_) => const AdminDashboardScreen(),
        '/partner-dashboard': (_) => const PartnerDashboardScreen(),
        '/partner-bookings': (_) => const PartnerBookingsScreen(),
        '/manage-rooms': (_) => const RoomManagementScreen(),
        '/profile/personal-info': (_) => const PersonalInfoScreen(),
        '/profile/transactions': (_) => const TransactionHistoryScreen(),
        '/profile/favorites': (_) => const FavoritesScreen(),
        '/manage-hotel-images': (_) => const HotelImageManagementScreen(),
      },
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/hotel':
            final hotel = settings.arguments as Hotel;
            return MaterialPageRoute(
              builder: (_) => HotelDetailScreen(hotel: hotel),
            );
          case '/booking':
            final room = settings.arguments as Room;
            return MaterialPageRoute(builder: (_) => BookingScreen(room: room));
          case '/payment':
            final booking = settings.arguments as Booking;
            return MaterialPageRoute(
              builder: (_) => PaymentScreen(booking: booking),
            );
          case '/review':
            final hotel = settings.arguments as Hotel;
            return MaterialPageRoute(
              builder: (_) => ReviewScreen(hotel: hotel),
            );
          case '/success':
            final args = Map<String, dynamic>.from(settings.arguments as Map);
            return MaterialPageRoute(
              builder: (_) => BookingSuccessScreen(
                booking: args['booking'] as Booking,
                payAmount: (args['payAmount'] as num).toDouble(),
                payMethod: args['payMethod'] as String,
                voucher: args['voucher'] as String?,
              ),
            );
        }
        return null;
      },
    );
  }
}
