import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(Cafe420());
}

class Cafe420 extends StatelessWidget {
  Cafe420({super.key, TrackerRepository? repository})
    : repository = repository ?? SqliteTrackerRepository.local();

  final TrackerRepository repository;

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF8A5A44);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );
    final textTheme = GoogleFonts.manropeTextTheme().apply(
      bodyColor: const Color(0xFF2F241D),
      displayColor: const Color(0xFF2F241D),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '420 Lifestyle',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF8F2E8),
        textTheme: textTheme,
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: TrackerHomePage(repository: repository),
    );
  }
}

class TrackerHomePage extends StatefulWidget {
  const TrackerHomePage({super.key, required this.repository});

  final TrackerRepository repository;

  @override
  State<TrackerHomePage> createState() => _TrackerHomePageState();
}

class _TrackerHomePageState extends State<TrackerHomePage> {
  late final TrackerRepository _repository;

  bool _isLoading = true;
  int _selectedTabIndex = 0;
  List<TrackerEvent> _events = const [];

  @override
  void initState() {
    super.initState();
    _repository = widget.repository;
    _loadEvents();
  }

  @override
  void dispose() {
    _repository.close();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    try {
      final events = await _repository.loadEvents();
      if (!mounted) {
        return;
      }
      setState(() {
        _events = events;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _showMessage('Could not load saved records.');
      });
    }
  }

  Future<void> _addEvent(HabitType type) async {
    try {
      final event = await _repository.insertEvent(type, DateTime.now());
      if (!mounted) {
        return;
      }
      setState(() {
        _events = [event, ..._events];
      });
      _showMessage('${type.pastTenseLabel} saved.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('Could not save that update.');
    }
  }

  Future<void> _removeEvent(HabitType type) async {
    final eventToRemove = _events.firstWhere(
      (event) => event.type == type,
      orElse: () =>
          TrackerEvent(type: HabitType.coffee, loggedAt: DateTime(1970)),
    );
    if (eventToRemove.id == null || eventToRemove.type != type) {
      _showMessage('No ${type.displayLabel.toLowerCase()} record to remove.');
      return;
    }

    try {
      await _repository.deleteEvent(eventToRemove.id!);
      if (!mounted) {
        return;
      }
      setState(() {
        _events = _events
            .where((event) => event.id != eventToRemove.id)
            .toList();
      });
      _showMessage('${type.displayLabel} removed.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('Could not save that update.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayEvents = _events
        .where((event) => event.isOnSameDay(now))
        .toList();
    final todayCoffee = _countForType(todayEvents, HabitType.coffee);
    final todayEggs = _countForType(todayEvents, HabitType.egg);
    final todayEggFries = _countForType(todayEvents, HabitType.eggFry);
    final totalCoffee = _countForType(_events, HabitType.coffee);
    final totalEggs = _countForType(_events, HabitType.egg);
    final totalEggFries = _countForType(_events, HabitType.eggFry);
    final totalLogged = _events.length;
    final summaries = _buildDailySummaries(_events);

    return Scaffold(
      bottomNavigationBar: _BottomNavBar(
        selectedIndex: _selectedTabIndex,
        onSelected: (index) {
          setState(() {
            _selectedTabIndex = index;
          });
        },
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF9F4EC), Color(0xFFF4F7F2)],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              top: -48,
              right: -30,
              child: _BackgroundBubble(size: 190, color: Color(0x1AD8A96D)),
            ),
            const Positioned(
              bottom: 120,
              left: -54,
              child: _BackgroundBubble(size: 170, color: Color(0x1AB8D7C0)),
            ),
            SafeArea(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                      children: [
                        if (_selectedTabIndex == 0) ...[
                          _AppHeader(dateLabel: _formatHeaderDate(now)),
                          const SizedBox(height: 20),
                          _TodayCard(
                            coffeeCount: todayCoffee,
                            eggCount: todayEggs,
                            eggFryCount: todayEggFries,
                            totalCount: todayEvents.length,
                          ),
                          const SizedBox(height: 16),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final halfWidth = (constraints.maxWidth - 12) / 2;
                              final isWide = constraints.maxWidth > 640;

                              if (isWide) {
                                final thirdWidth =
                                    (constraints.maxWidth - 24) / 3;
                                return Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    SizedBox(
                                      width: thirdWidth,
                                      child: _QuickLogButton(
                                        type: HabitType.egg,
                                        todayCount: todayEggs,
                                        onIncrease: () =>
                                            _addEvent(HabitType.egg),
                                        onDecrease: todayEggs > 0
                                            ? () => _removeEvent(HabitType.egg)
                                            : null,
                                      ),
                                    ),
                                    SizedBox(
                                      width: thirdWidth,
                                      child: _QuickLogButton(
                                        type: HabitType.eggFry,
                                        todayCount: todayEggFries,
                                        onIncrease: () =>
                                            _addEvent(HabitType.eggFry),
                                        onDecrease: todayEggFries > 0
                                            ? () =>
                                                  _removeEvent(HabitType.eggFry)
                                            : null,
                                      ),
                                    ),
                                    SizedBox(
                                      width: thirdWidth,
                                      child: _QuickLogButton(
                                        type: HabitType.coffee,
                                        todayCount: todayCoffee,
                                        onIncrease: () =>
                                            _addEvent(HabitType.coffee),
                                        onDecrease: todayCoffee > 0
                                            ? () =>
                                                  _removeEvent(HabitType.coffee)
                                            : null,
                                      ),
                                    ),
                                  ],
                                );
                              }

                              return Column(
                                children: [
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: halfWidth,
                                        child: _QuickLogButton(
                                          type: HabitType.egg,
                                          todayCount: todayEggs,
                                          onIncrease: () =>
                                              _addEvent(HabitType.egg),
                                          onDecrease: todayEggs > 0
                                              ? () =>
                                                    _removeEvent(HabitType.egg)
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      SizedBox(
                                        width: halfWidth,
                                        child: _QuickLogButton(
                                          type: HabitType.eggFry,
                                          todayCount: todayEggFries,
                                          onIncrease: () =>
                                              _addEvent(HabitType.eggFry),
                                          onDecrease: todayEggFries > 0
                                              ? () => _removeEvent(
                                                  HabitType.eggFry,
                                                )
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: _QuickLogButton(
                                      type: HabitType.coffee,
                                      todayCount: todayCoffee,
                                      onIncrease: () =>
                                          _addEvent(HabitType.coffee),
                                      onDecrease: todayCoffee > 0
                                          ? () => _removeEvent(HabitType.coffee)
                                          : null,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final wide = constraints.maxWidth > 640;
                              final cardWidth = wide
                                  ? (constraints.maxWidth - 24) / 3
                                  : (constraints.maxWidth - 12) / 2;

                              return Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  SizedBox(
                                    width: cardWidth,
                                    child: _StatCard(
                                      label: 'All coffee',
                                      value: '$totalCoffee',
                                      accent: HabitType.coffee.accent,
                                    ),
                                  ),
                                  SizedBox(
                                    width: cardWidth,
                                    child: _StatCard(
                                      label: 'All boiled eggs',
                                      value: '$totalEggs',
                                      accent: HabitType.egg.accent,
                                    ),
                                  ),
                                  SizedBox(
                                    width: cardWidth,
                                    child: _StatCard(
                                      label: 'All egg fry',
                                      value: '$totalEggFries',
                                      accent: HabitType.eggFry.accent,
                                    ),
                                  ),
                                  SizedBox(
                                    width: cardWidth,
                                    child: _StatCard(
                                      label: 'Days tracked',
                                      value: '${summaries.length}',
                                      accent: const Color(0xFF4F8365),
                                    ),
                                  ),
                                  SizedBox(
                                    width: cardWidth,
                                    child: _StatCard(
                                      label: 'All logs',
                                      value: '$totalLogged',
                                      accent: const Color(0xFF6C7B9A),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ] else if (_selectedTabIndex == 1) ...[
                          const _SectionTitle(
                            title: 'Recent Days',
                            subtitle: "A quick glance at each day's totals.",
                          ),
                          const SizedBox(height: 12),
                          if (summaries.isEmpty)
                            const _EmptyStateCard(
                              title: 'No recent days yet',
                              message:
                                  'Your daily totals will appear here after you start logging.',
                            )
                          else
                            Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  children: summaries
                                      .take(7)
                                      .map(
                                        (summary) =>
                                            _DaySummaryTile(summary: summary),
                                      )
                                      .toList(),
                                ),
                              ),
                            ),
                        ] else ...[
                          const _SectionTitle(
                            title: 'Records',
                            subtitle:
                                'Use + to save a record and - to remove one.',
                          ),
                          const SizedBox(height: 12),
                          if (_events.isEmpty)
                            const _EmptyStateCard()
                          else
                            Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  children: _events
                                      .take(12)
                                      .map((event) => _RecordTile(event: event))
                                      .toList(),
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFF0E4D8)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _BottomNavItem(
                  label: 'Home',
                  icon: Icons.home_rounded,
                  isSelected: selectedIndex == 0,
                  onTap: () => onSelected(0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BottomNavItem(
                  label: 'Recent Days',
                  icon: Icons.calendar_month_rounded,
                  isSelected: selectedIndex == 1,
                  onTap: () => onSelected(1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BottomNavItem(
                  label: 'Records',
                  icon: Icons.receipt_long_rounded,
                  isSelected: selectedIndex == 2,
                  onTap: () => onSelected(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = const Color(0xFFB749D8);
    final inactiveColor = const Color(0xFF2F241D);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFFF1DFF8), Color(0xFFF7EAFD)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 28,
                color: isSelected ? activeColor : inactiveColor,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isSelected ? activeColor : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader({required this.dateLabel});

  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '420 Lifestyle',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Use the + and - buttons to update each count.',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF66564C)),
        ),
        const SizedBox(height: 10),
        Text(
          dateLabel,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: const Color(0xFF8E7768),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.coffeeCount,
    required this.eggCount,
    required this.eggFryCount,
    required this.totalCount,
  });

  final int coffeeCount;
  final int eggCount;
  final int eggFryCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFFFF), Color(0xFFF4EADF)],
          ),
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: Text(
                '$totalCount',
                key: ValueKey(totalCount),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.4,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              totalCount == 1 ? 'total log' : 'total logs',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF7A6759)),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _CountPill(
                  icon: HabitType.coffee.icon,
                  label: 'Coffee',
                  count: coffeeCount,
                  color: HabitType.coffee.accent,
                ),
                _CountPill(
                  icon: HabitType.egg.icon,
                  label: 'Boiled egg',
                  count: eggCount,
                  color: HabitType.egg.accent,
                ),
                _CountPill(
                  icon: HabitType.eggFry.icon,
                  label: 'Egg fry',
                  count: eggFryCount,
                  color: HabitType.eggFry.accent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            '$label: $count',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFF473A30),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickLogButton extends StatelessWidget {
  const _QuickLogButton({
    required this.type,
    required this.todayCount,
    required this.onIncrease,
    required this.onDecrease,
  });

  final HabitType type;
  final int todayCount;
  final VoidCallback onIncrease;
  final VoidCallback? onDecrease;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: type.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(type.icon, color: type.accent),
          ),
          const SizedBox(height: 18),
          Text(
            type.actionLabel,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap + or - to update',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6D5A4D)),
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Text(
              'Today: $todayCount',
              key: ValueKey('${type.storageKey}-$todayCount'),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: type.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _TrackerActionButton(
                  key: ValueKey('${type.storageKey}-decrease'),
                  icon: Icons.remove_rounded,
                  isPrimary: false,
                  accent: type.accent,
                  onPressed: onDecrease,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TrackerActionButton(
                  key: ValueKey('${type.storageKey}-increase'),
                  icon: Icons.add_rounded,
                  isPrimary: true,
                  accent: type.accent,
                  onPressed: onIncrease,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrackerActionButton extends StatelessWidget {
  const _TrackerActionButton({
    super.key,
    required this.icon,
    required this.isPrimary,
    required this.accent,
    required this.onPressed,
  });

  final IconData icon;
  final bool isPrimary;
  final Color accent;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isPrimary
                ? accent.withValues(alpha: isEnabled ? 0.95 : 0.35)
                : Colors.white.withValues(alpha: isEnabled ? 0.78 : 0.45),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isPrimary
                  ? Colors.transparent
                  : accent.withValues(alpha: isEnabled ? 0.22 : 0.1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: isPrimary
                    ? Colors.white
                    : accent.withValues(alpha: isEnabled ? 1 : 0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 10,
              width: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF715F53)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF776658)),
        ),
      ],
    );
  }
}

class _DaySummaryTile extends StatelessWidget {
  const _DaySummaryTile({required this.summary});

  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(
        _formatDayLabel(summary.date),
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          'Coffee ${summary.coffeeCount}  •  Boiled eggs ${summary.eggCount}  •  Egg fry ${summary.eggFryCount}',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF7D685A)),
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF4EFE8),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          '${summary.totalCount}',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.event});

  final TrackerEvent event;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      leading: CircleAvatar(
        backgroundColor: event.type.accent.withValues(alpha: 0.14),
        foregroundColor: event.type.accent,
        child: Icon(event.type.icon),
      ),
      title: Text(
        event.type.pastTenseLabel,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          _formatRecordTimestamp(event.loggedAt),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF7A6758)),
        ),
      ),
      trailing: Text(
        _formatTimeLabel(event.loggedAt),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: const Color(0xFF8B7768),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    this.title = 'No records yet',
    this.message =
        'Tap Increase on coffee, boiled egg, or egg fry, and the app will save that record for you.',
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFF1E8DD),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.touch_app_rounded),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF705F53)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackgroundBubble extends StatelessWidget {
  const _BackgroundBubble({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

enum HabitType { coffee, egg, eggFry }

extension HabitTypeDetails on HabitType {
  String get displayLabel => switch (this) {
    HabitType.coffee => 'Coffee',
    HabitType.egg => 'Boiled egg',
    HabitType.eggFry => 'Egg Fry',
  };

  String get storageKey => switch (this) {
    HabitType.coffee => 'coffee',
    HabitType.egg => 'egg',
    HabitType.eggFry => 'egg_fry',
  };

  String get actionLabel => switch (this) {
    HabitType.coffee => 'Made coffee',
    HabitType.egg => 'Boiled egg',
    HabitType.eggFry => 'Egg Fry',
  };

  String get pastTenseLabel => switch (this) {
    HabitType.coffee => 'Coffee logged',
    HabitType.egg => 'Egg logged',
    HabitType.eggFry => 'Egg Fry logged',
  };

  IconData get icon => switch (this) {
    HabitType.coffee => Icons.coffee_rounded,
    HabitType.egg => Icons.breakfast_dining_rounded,
    HabitType.eggFry => Icons.egg_alt_rounded,
  };

  Color get accent => switch (this) {
    HabitType.coffee => const Color(0xFF8A5A44),
    HabitType.egg => const Color(0xFFB7862E),
    HabitType.eggFry => const Color(0xFFCF6F4A),
  };
}

class TrackerEvent {
  const TrackerEvent({this.id, required this.type, required this.loggedAt});

  final int? id;
  final HabitType type;
  final DateTime loggedAt;

  Map<String, dynamic> toJson() {
    return {'type': type.storageKey, 'loggedAt': loggedAt.toIso8601String()};
  }

  factory TrackerEvent.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String? ?? HabitType.coffee.storageKey;
    return TrackerEvent(
      type: HabitType.values.firstWhere(
        (type) => type.storageKey == typeName,
        orElse: () => HabitType.coffee,
      ),
      loggedAt: DateTime.parse(json['loggedAt'] as String),
    );
  }

  factory TrackerEvent.fromDatabase(Map<String, Object?> row) {
    final typeName = row['type'] as String? ?? HabitType.coffee.storageKey;
    return TrackerEvent(
      id: row['id'] as int,
      type: HabitType.values.firstWhere(
        (type) => type.storageKey == typeName,
        orElse: () => HabitType.coffee,
      ),
      loggedAt: DateTime.parse(row['logged_at'] as String),
    );
  }

  Map<String, Object?> toDatabase() {
    return {'type': type.storageKey, 'logged_at': loggedAt.toIso8601String()};
  }

  TrackerEvent copyWith({int? id, HabitType? type, DateTime? loggedAt}) {
    return TrackerEvent(
      id: id ?? this.id,
      type: type ?? this.type,
      loggedAt: loggedAt ?? this.loggedAt,
    );
  }

  bool isOnSameDay(DateTime date) {
    return loggedAt.year == date.year &&
        loggedAt.month == date.month &&
        loggedAt.day == date.day;
  }
}

class DailySummary {
  const DailySummary({
    required this.date,
    required this.coffeeCount,
    required this.eggCount,
    required this.eggFryCount,
  });

  final DateTime date;
  final int coffeeCount;
  final int eggCount;
  final int eggFryCount;

  int get totalCount => coffeeCount + eggCount + eggFryCount;

  DailySummary copyWith({int? coffeeCount, int? eggCount, int? eggFryCount}) {
    return DailySummary(
      date: date,
      coffeeCount: coffeeCount ?? this.coffeeCount,
      eggCount: eggCount ?? this.eggCount,
      eggFryCount: eggFryCount ?? this.eggFryCount,
    );
  }
}

abstract class TrackerRepository {
  Future<List<TrackerEvent>> loadEvents();
  Future<TrackerEvent> insertEvent(HabitType type, DateTime loggedAt);
  Future<void> deleteEvent(int id);
  Future<void> close();
}

class SqliteTrackerRepository implements TrackerRepository {
  SqliteTrackerRepository.local({
    sqflite.DatabaseFactory? databaseFactory,
    String? databasePath,
  }) : _databaseFactory = databaseFactory ?? _resolveDatabaseFactory(),
       _databasePath = databasePath;

  static const _databaseName = 'cafe420_tracker.db';
  static const _legacyEventsKey = 'kitchen_tally_events_v1';
  static const _migrationFlagKey = 'tracker_events_db_migrated_v1';

  final sqflite.DatabaseFactory _databaseFactory;
  final String? _databasePath;
  sqflite.Database? _database;

  @override
  Future<List<TrackerEvent>> loadEvents() async {
    final database = await _openDatabase();
    final rows = await database.query(
      'tracker_events',
      orderBy: 'logged_at DESC, id DESC',
    );

    return rows.map(TrackerEvent.fromDatabase).toList();
  }

  @override
  Future<TrackerEvent> insertEvent(HabitType type, DateTime loggedAt) async {
    final database = await _openDatabase();
    final event = TrackerEvent(type: type, loggedAt: loggedAt);
    final id = await database.insert('tracker_events', event.toDatabase());
    return event.copyWith(id: id);
  }

  @override
  Future<void> deleteEvent(int id) async {
    final database = await _openDatabase();
    await database.delete('tracker_events', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> close() async {
    if (_database == null) {
      return;
    }

    await _database!.close();
    _database = null;
  }

  Future<sqflite.Database> _openDatabase() async {
    if (_database != null) {
      return _database!;
    }

    final databasePath =
        _databasePath ??
        path.join(await _databaseFactory.getDatabasesPath(), _databaseName);

    final database = await _databaseFactory.openDatabase(
      databasePath,
      options: sqflite.OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE tracker_events (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              type TEXT NOT NULL,
              logged_at TEXT NOT NULL
            )
          ''');
          await db.execute(
            'CREATE INDEX idx_tracker_events_logged_at ON tracker_events(logged_at DESC)',
          );
        },
      ),
    );

    await _migrateLegacyPreferencesIfNeeded(database);
    _database = database;
    return database;
  }

  Future<void> _migrateLegacyPreferencesIfNeeded(
    sqflite.Database database,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyMigrated = prefs.getBool(_migrationFlagKey) ?? false;
    if (alreadyMigrated) {
      return;
    }

    final existingCount =
        sqflite.Sqflite.firstIntValue(
          await database.rawQuery('SELECT COUNT(*) FROM tracker_events'),
        ) ??
        0;

    if (existingCount == 0) {
      final raw = prefs.getString(_legacyEventsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        final events =
            decoded
                .map(
                  (item) => TrackerEvent.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ),
                )
                .toList()
              ..sort((left, right) => left.loggedAt.compareTo(right.loggedAt));

        final batch = database.batch();
        for (final event in events) {
          batch.insert('tracker_events', event.toDatabase());
        }
        await batch.commit(noResult: true);
        await prefs.remove(_legacyEventsKey);
      }
    }

    await prefs.setBool(_migrationFlagKey, true);
  }

  static sqflite.DatabaseFactory _resolveDatabaseFactory() {
    if (kIsWeb) {
      throw UnsupportedError(
        'Web is not supported for local database storage.',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        sqfliteFfiInit();
        return databaseFactoryFfi;
      default:
        return sqflite.databaseFactory;
    }
  }
}

int _countForType(List<TrackerEvent> events, HabitType type) {
  return events.where((event) => event.type == type).length;
}

List<DailySummary> _buildDailySummaries(List<TrackerEvent> events) {
  final summariesByDay = <String, DailySummary>{};

  for (final event in events) {
    final day = DateTime(
      event.loggedAt.year,
      event.loggedAt.month,
      event.loggedAt.day,
    );
    final key = day.toIso8601String();
    final current = summariesByDay[key];

    if (current == null) {
      summariesByDay[key] = DailySummary(
        date: day,
        coffeeCount: event.type == HabitType.coffee ? 1 : 0,
        eggCount: event.type == HabitType.egg ? 1 : 0,
        eggFryCount: event.type == HabitType.eggFry ? 1 : 0,
      );
      continue;
    }

    summariesByDay[key] = current.copyWith(
      coffeeCount:
          current.coffeeCount + (event.type == HabitType.coffee ? 1 : 0),
      eggCount: current.eggCount + (event.type == HabitType.egg ? 1 : 0),
      eggFryCount:
          current.eggFryCount + (event.type == HabitType.eggFry ? 1 : 0),
    );
  }

  final summaries = summariesByDay.values.toList()
    ..sort((left, right) => right.date.compareTo(left.date));
  return summaries;
}

String _formatHeaderDate(DateTime date) {
  return '${_weekdayNamesLong[date.weekday - 1]}, ${_monthNamesLong[date.month - 1]} ${date.day}';
}

String _formatDayLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final difference = today.difference(target).inDays;

  if (difference == 0) {
    return 'Today';
  }
  if (difference == 1) {
    return 'Yesterday';
  }

  return '${_weekdayNamesShort[date.weekday - 1]}, ${_monthNamesShort[date.month - 1]} ${date.day}';
}

String _formatRecordTimestamp(DateTime date) {
  return '${_formatDayLabel(date)} at ${_formatTimeLabel(date)}';
}

String _formatTimeLabel(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final suffix = date.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

const _weekdayNamesShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

const _weekdayNamesLong = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _monthNamesShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const _monthNamesLong = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
