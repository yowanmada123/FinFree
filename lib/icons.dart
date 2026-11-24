import 'package:flutter/material.dart';

/// Registry ikon aplikasi. Ikon disimpan sebagai key string sehingga tetap
/// konstan (aman untuk tree-shaking icon font saat build release).
const Map<String, IconData> kIcons = {
  // pengeluaran
  'food': Icons.ramen_dining_rounded,
  'coffee': Icons.local_cafe_rounded,
  'grocery': Icons.shopping_basket_rounded,
  'transport': Icons.two_wheeler_rounded,
  'fuel': Icons.local_gas_station_rounded,
  'car': Icons.directions_car_filled_rounded,
  'bills': Icons.receipt_long_rounded,
  'electric': Icons.bolt_rounded,
  'water': Icons.water_drop_rounded,
  'internet': Icons.wifi_rounded,
  'phone': Icons.smartphone_rounded,
  'home': Icons.cottage_rounded,
  'shopping': Icons.local_mall_rounded,
  'clothes': Icons.checkroom_rounded,
  'health': Icons.healing_rounded,
  'education': Icons.auto_stories_rounded,
  'entertain': Icons.sports_esports_rounded,
  'movie': Icons.theaters_rounded,
  'travel': Icons.luggage_rounded,
  'gift': Icons.card_giftcard_rounded,
  'charity': Icons.volunteer_activism_rounded,
  'baby': Icons.child_friendly_rounded,
  'pet': Icons.pets_rounded,
  'sport': Icons.fitness_center_rounded,
  'beauty': Icons.spa_rounded,
  'tools': Icons.handyman_rounded,
  'insurance': Icons.health_and_safety_rounded,
  'tax': Icons.account_balance_rounded,
  'debt': Icons.credit_score_rounded,
  'handshake': Icons.handshake_rounded,
  'other': Icons.category_rounded,
  // pemasukan
  'salary': Icons.work_rounded,
  'bonus': Icons.emoji_events_rounded,
  'business': Icons.storefront_rounded,
  'invest': Icons.trending_up_rounded,
  'interest': Icons.percent_rounded,
  'freelance': Icons.laptop_mac_rounded,
  'refund': Icons.currency_exchange_rounded,
  'income_other': Icons.add_card_rounded,
  // dompet
  'wallet': Icons.account_balance_wallet_rounded,
  'cash': Icons.payments_rounded,
  'bank': Icons.account_balance_rounded,
  'card': Icons.credit_card_rounded,
  'ewallet': Icons.qr_code_2_rounded,
  'savings': Icons.savings_rounded,
  // aset / dagangan
  'smartphone_box': Icons.phone_iphone_rounded,
  'inventory': Icons.inventory_2_rounded,
  'laptop': Icons.laptop_chromebook_rounded,
  'watch': Icons.watch_rounded,
  'camera': Icons.photo_camera_rounded,
  'motorbike': Icons.moped_rounded,
  'gold': Icons.diamond_rounded,
  'property': Icons.villa_rounded,
  'store': Icons.store_mall_directory_rounded,
};

IconData iconOf(String key) => kIcons[key] ?? Icons.category_rounded;

const List<int> kColors = [
  0xFF00897B, 0xFF43A047, 0xFF7CB342, 0xFFF9A825, 0xFFFB8C00,
  0xFFF4511E, 0xFFE53935, 0xFFD81B60, 0xFF8E24AA, 0xFF5E35B1,
  0xFF3949AB, 0xFF1E88E5, 0xFF039BE5, 0xFF00ACC1, 0xFF6D4C41,
  0xFF546E7A,
];

class CircleIcon extends StatelessWidget {
  final String icon;
  final int color;
  final double size;
  const CircleIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final c = Color(color);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(iconOf(icon), color: c, size: size * 0.55),
    );
  }
}
