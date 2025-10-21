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
import 'package:stayeasy/screens/room_management_screen.dart';
import 'package:stayeasy/state/auth_state.dart';
import 'package:stayeasy/models/booking.dart';
import 'package:stayeasy/models/hotel.dart';
import 'package:stayeasy/models/room.dart';
import 'config/stripe_config.dart';
import 'config/theme.dart';

const kBrandBlue = Color(0xFF1E88E5);
const kRadius = 16.0;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  stripe.Stripe.publishableKey = StripeConfig.publishableKey;
  await stripe.Stripe.instance.applySettings();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AuthState.I.loadFromStorage();
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
        '/voucher': (_) => const VoucherScreen(),
        '/admin-dashboard': (_) => const AdminDashboardScreen(),
        '/partner-dashboard': (_) => const PartnerDashboardScreen(),
        '/manage-rooms': (_) => const RoomManagementScreen(),
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
