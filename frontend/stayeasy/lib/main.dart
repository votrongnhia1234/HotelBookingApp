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
    final base = ThemeData(useMaterial3: true);

    return MaterialApp(
      title: 'StayEasy',
      debugShowCheckedModeBanner: false,
      initialRoute: '/splash',
      theme: base.copyWith(
        colorScheme: base.colorScheme.copyWith(
          primary: kBrandBlue,
          secondary: const Color(0xFF2E3A59),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F9FB),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kRadius),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: kBrandBlue,
          unselectedItemColor: Color(0xFFBDBDBD),
          showUnselectedLabels: true,
          selectedLabelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          selectedIconTheme: IconThemeData(size: 22),
          unselectedIconTheme: IconThemeData(size: 22),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide(color: kBrandBlue, width: 1.4),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kBrandBlue,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
        ),
        dividerTheme: DividerThemeData(
          color: Colors.grey.shade200,
          space: 24,
          thickness: 1,
        ),
      ),
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
