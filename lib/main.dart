import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KitchenTallyApp());
}

class KitchenTallyApp extends StatelessWidget {
  const KitchenTallyApp({super.key});

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
      home: const TrackerHomePage(),
    );
  }
}

class TrackerHomePage extends StatefulWidget {
  const TrackerHomePage({super.key});

  @override
  State<TrackerHomePage> createState() => _TrackerHomePageState();
}

class _TrackerHomePageState extends State<TrackerHomePage> {
  final TrackerRepository _repository = const TrackerRepository();
  Future<void> _saveQueue = Future<void>.value();

  bool _isLoading = true;
  List<TrackerEvent> _events = const [];

  @override
  void initState() {
    super.initState();
    _loadEvents();
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
    final event = TrackerEvent(type: type, loggedAt: DateTime.now());
    final updatedEvents = [event, ..._events];

    setState(() {
      _events = updatedEvents;
    });

    _saveQueue = _saveQueue.then((_) => _repository.saveEvents(updatedEvents));
    try {
      await _saveQueue;
      if (!mounted) {
        return;
      }
      _showMessage('${type.pastTenseLabel} saved.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('Could not save that update.');
    }
  }

  Future<void> _removeEvent(HabitType type) async {
    final removalIndex = _events.indexWhere((event) => event.type == type);
    if (removalIndex == -1) {
      _showMessage('No ${type.displayLabel.toLowerCase()} record to remove.');
      return;
    }

    final updatedEvents = List<TrackerEvent>.from(_events)
      ..removeAt(removalIndex);

    setState(() {
      _events = updatedEvents;
    });

    _saveQueue = _saveQueue.then((_) => _repository.saveEvents(updatedEvents));
    try {
      await _saveQueue;
      if (!mounted) {
        return;
      }
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
                                          ? () => _removeEvent(HabitType.eggFry)
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
                                          ? () => _removeEvent(HabitType.coffee)
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
                                            ? () => _removeEvent(HabitType.egg)
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
                                            ? () =>
                                                  _removeEvent(HabitType.eggFry)
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
                        if (summaries.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const _SectionTitle(
                            title: 'Recent Days',
                            subtitle: 'A quick glance at each day\'s totals.',
                          ),
                          const SizedBox(height: 12),
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
                        ],
                        const SizedBox(height: 24),
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
                    ),
            ),
          ],
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
  const _EmptyStateCard();

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
              'No records yet',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap Increase on coffee, boiled egg, or egg fry, and the app will save that record for you.',
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
  const TrackerEvent({required this.type, required this.loggedAt});

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

class TrackerRepository {
  const TrackerRepository();

  static const _eventsKey = 'kitchen_tally_events_v1';

  Future<List<TrackerEvent>> loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_eventsKey);

    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    final events = decoded
        .map(
          (item) =>
              TrackerEvent.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();

    events.sort((left, right) => right.loggedAt.compareTo(left.loggedAt));
    return events;
  }

  Future<void> saveEvents(List<TrackerEvent> events) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(events.map((event) => event.toJson()).toList());
    await prefs.setString(_eventsKey, raw);
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
