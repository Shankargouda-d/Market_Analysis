import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import '../services/local_storage_service.dart';
import '../services/sheets_service.dart';
import '../widgets/page_indicator.dart';
import 'analytics_screen.dart';
import 'buy_screen.dart';
import 'expenditure_screen.dart';
import 'farmer_details_screen.dart';
import 'factory_details_screen.dart';
import 'login_screen.dart';
import 'sell_screen.dart';
import 'worker_details_screen.dart';

/// The single screen registered in main.dart. It hosts a PageView so
/// the user can swipe left/right between Buy, Sell, Expenditure, Analytics,
/// Farmer Details, Factory Details, and Worker Details, with top tabs and bottom navigation.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PageController _controller = PageController();
  int _index = 0;

  final _titles = const [
    'Buy',
    'Sell',
    'Other Expenditure',
    'Analytics',
    'Farmer Details',
    'Factory Details',
    'Worker Details'
  ];
  final _shortTitles = const [
    'Buy',
    'Sell',
    'Expenditure',
    'Analytics',
    'Farmers',
    'Factories',
    'Workers'
  ];
  final _icons = const [
    Icons.shopping_cart,
    Icons.storefront,
    Icons.receipt_long,
    Icons.bar_chart,
    Icons.agriculture,
    Icons.factory,
    Icons.engineering,
  ];
  final _outlinedIcons = const [
    Icons.shopping_cart_outlined,
    Icons.storefront_outlined,
    Icons.receipt_long_outlined,
    Icons.bar_chart_outlined,
    Icons.agriculture_outlined,
    Icons.factory_outlined,
    Icons.engineering_outlined,
  ];
  final _colors = const [
    AppColors.buy,
    AppColors.sell,
    AppColors.expenditure,
    AppColors.analytics,
    AppColors.farmer,
    AppColors.factory,
    AppColors.worker,
  ];

  void _goTo(int i) {
    _controller.animateToPage(
      i,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _confirmLogout() {
    final userId = AuthService.currentUserId ?? 'User';
    final isProd = AuthService.isProduction;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.logout_rounded,
                color: isProd ? AppColors.primary : Colors.amber.shade800),
            const SizedBox(width: 10),
            const Text('Switch Environment',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Currently active User ID: $userId',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isProd
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                AuthService.environmentName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isProd ? AppColors.primary : Colors.amber.shade900,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Logging out will return you to the login screen where you can switch between MarketP (Production) and MarketT (Testing).',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await AuthService.logout();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  void _showSheetsDialog() {
    final isProd = AuthService.isProduction;
    final env = AuthService.currentUserId ?? 'MarketP';

    showDialog(
      context: context,
      builder: (ctx) {
        bool syncing = false;
        String? resultMessage;

        return StatefulBuilder(
          builder: (context, setModalState) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.table_chart, color: Colors.green),
                SizedBox(width: 10),
                Text('Google Sheets Sync',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active Environment: $env (${isProd ? "Production" : "Test"})',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sync your Supabase records (purchases, sales, farmers, factories, workers) into your connected Google Spreadsheet.',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                if (resultMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            resultMessage!,
                            style: const TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                icon: syncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.sync, size: 18),
                label: Text(syncing ? 'Syncing...' : 'Sync to Sheets Now'),
                onPressed: syncing
                    ? null
                    : () async {
                        setModalState(() => syncing = true);
                        final ok = await SheetsService.triggerSupabaseSync();
                        setModalState(() {
                          syncing = false;
                          resultMessage = ok
                              ? 'Successfully exported $env records to Google Sheets!'
                              : 'Sync triggered! Check Google Sheets ($env sheet tabs).';
                        });
                      },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmClearLocalStorage() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep, color: Colors.red),
            SizedBox(width: 10),
            Text('Clear Local Data',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Are you sure you want to remove the entire local data from this device? All offline cached purchases, sales, farmers, factories, and workers will be wiped clean.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await LocalStorageService.clearAllData();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All local data has been completely removed!'),
                  backgroundColor: Colors.green,
                ),
              );
              // Trigger app rebuild
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomePage()),
                (route) => false,
              );
            },
            child: const Text('Remove All Data'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: _colors[_index],
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_titles[_index]),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AuthService.isProduction
                        ? Icons.verified
                        : Icons.science_outlined,
                    size: 13,
                    color: AuthService.isProduction
                        ? const Color(0xFFB9F6CA)
                        : const Color(0xFFFFE082),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    AuthService.currentUserId ?? 'MarketP',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AuthService.isProduction
                          ? const Color(0xFFB9F6CA)
                          : const Color(0xFFFFE082),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart_outlined),
            tooltip: 'Google Sheets Export',
            onPressed: _showSheetsDialog,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear All Local Data',
            onPressed: _confirmClearLocalStorage,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Switch User / Logout',
            onPressed: _confirmLogout,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _goTo,
          backgroundColor: AppColors.cardBackground,
          indicatorColor: _colors[_index].withValues(alpha: 0.18),
          height: 65,
          destinations: List.generate(7, (i) {
            return NavigationDestination(
              icon: Icon(_outlinedIcons[i]),
              selectedIcon: Icon(_icons[i], color: _colors[i]),
              label: _shortTitles[i],
            );
          }),
        ),
      ),
      body: Column(
        children: [
          _TopTabs(
            titles: _shortTitles,
            icons: _icons,
            colors: _colors,
            currentIndex: _index,
            onTap: _goTo,
          ),
          Expanded(
            child: PageView(
              controller: _controller,
              onPageChanged: (i) => setState(() => _index = i),
              children: const [
                BuyScreen(),
                SellScreen(),
                ExpenditureScreen(),
                AnalyticsScreen(),
                FarmerDetailsScreen(),
                FactoryDetailsScreen(),
                WorkerDetailsScreen(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: PageIndicator(count: 7, currentIndex: _index),
          ),
        ],
      ),
    );
  }
}

class _TopTabs extends StatelessWidget {
  final List<String> titles;
  final List<IconData> icons;
  final List<Color> colors;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _TopTabs({
    required this.titles,
    required this.icons,
    required this.colors,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cardBackground,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(titles.length, (i) {
            final active = i == currentIndex;
            return GestureDetector(
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                decoration: BoxDecoration(
                  color: active
                      ? colors[i].withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: active ? colors[i] : AppColors.divider,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icons[i],
                      size: 16,
                      color: active ? colors[i] : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      titles[i],
                      style: TextStyle(
                        fontSize: 12,
                        color: active ? colors[i] : AppColors.textSecondary,
                        fontWeight:
                            active ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
