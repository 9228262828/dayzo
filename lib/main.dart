import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _dayzoPurple = Color(0xFF6A35FF);
const _dayzoDeepPurple = Color(0xFF35166F);
const _dayzoOrange = Color(0xFFFF8A3D);
const _dayzoGold = Color(0xFFFFC15E);
const _eventsStorageKey = 'dayzo.events.v1';
const _darkModeStorageKey = 'dayzo.darkMode.v1';
const _appVersion = '1.0.0';
const _appBuild = '1';
const _lastUpdated = 'June 23, 2026';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }

    setState(() {
      _darkMode = preferences.getBool(_darkModeStorageKey) ?? false;
    });
  }

  Future<void> _setDarkMode(bool enabled) async {
    setState(() {
      _darkMode = enabled;
    });

    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_darkModeStorageKey, enabled);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dayzo - Countdown & Event Tracker',
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: DayzoHomePage(
        darkMode: _darkMode,
        onDarkModeChanged: _setDarkMode,
      ),
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: _dayzoPurple,
    brightness: brightness,
  ).copyWith(
    primary: _dayzoPurple,
    secondary: _dayzoOrange,
    tertiary: _dayzoGold,
    surface: isDark ? const Color(0xFF171321) : const Color(0xFFFFFBFF),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: isDark ? const Color(0xFF100D17) : const Color(0xFFFFFBFF),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      titleTextStyle: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 22,
        fontWeight: FontWeight.w800,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: isDark ? const Color(0xFF201A2D) : Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: _dayzoOrange,
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _dayzoPurple, width: 2),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

class DayzoEvent {
  DayzoEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.createdAt,
  });

  final String id;
  final String title;
  final DateTime date;
  final DateTime createdAt;

  DateTime get dateOnly => DateTime(date.year, date.month, date.day);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'date': dateOnly.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory DayzoEvent.fromJson(Map<String, dynamic> json) {
    final parsedDate = DateTime.parse(json['date'] as String);
    return DayzoEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      date: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  DayzoEvent copyWith({
    String? title,
    DateTime? date,
  }) {
    return DayzoEvent(
      id: id,
      title: title ?? this.title,
      date: date ?? this.date,
      createdAt: createdAt,
    );
  }
}

class DayzoHomePage extends StatefulWidget {
  const DayzoHomePage({
    super.key,
    required this.darkMode,
    required this.onDarkModeChanged,
  });

  final bool darkMode;
  final ValueChanged<bool> onDarkModeChanged;

  @override
  State<DayzoHomePage> createState() => _DayzoHomePageState();
}

class _DayzoHomePageState extends State<DayzoHomePage> {
  final List<DayzoEvent> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _loadEvents() async {
    final preferences = await SharedPreferences.getInstance();
    final encodedEvents = preferences.getString(_eventsStorageKey);
    final loadedEvents = <DayzoEvent>[];

    if (encodedEvents != null && encodedEvents.isNotEmpty) {
      try {
        final decoded = jsonDecode(encodedEvents) as List<dynamic>;
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            loadedEvents.add(DayzoEvent.fromJson(item));
          } else if (item is Map) {
            loadedEvents.add(DayzoEvent.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      } catch (_) {
        loadedEvents.clear();
      }
    }

    loadedEvents.sort(_compareEvents);
    if (!mounted) {
      return;
    }

    setState(() {
      _events
        ..clear()
        ..addAll(loadedEvents);
      _loading = false;
    });
  }

  Future<void> _saveEvents() async {
    _events.sort(_compareEvents);
    final preferences = await SharedPreferences.getInstance();
    final encodedEvents = jsonEncode(_events.map((event) => event.toJson()).toList());
    await preferences.setString(_eventsStorageKey, encodedEvents);
  }

  int _compareEvents(DayzoEvent a, DayzoEvent b) {
    final today = _today;
    final aPast = a.dateOnly.isBefore(today);
    final bPast = b.dateOnly.isBefore(today);

    if (aPast != bPast) {
      return aPast ? 1 : -1;
    }

    if (aPast && bPast) {
      return b.dateOnly.compareTo(a.dateOnly);
    }

    final dateComparison = a.dateOnly.compareTo(b.dateOnly);
    if (dateComparison != 0) {
      return dateComparison;
    }

    return a.createdAt.compareTo(b.createdAt);
  }

  Future<void> _upsertEvent(DayzoEvent event) async {
    final existingIndex = _events.indexWhere((storedEvent) => storedEvent.id == event.id);
    setState(() {
      if (existingIndex == -1) {
        _events.add(event);
      } else {
        _events[existingIndex] = event;
      }
      _events.sort(_compareEvents);
    });

    await _saveEvents();
  }

  Future<void> _showEventForm([DayzoEvent? event]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return EventFormSheet(
          event: event,
          onSave: (title, date) async {
            final savedEvent = event == null
                ? DayzoEvent(
                    id: DateTime.now().microsecondsSinceEpoch.toString(),
                    title: title,
                    date: date,
                    createdAt: DateTime.now(),
                  )
                : event.copyWith(title: title, date: date);

            await _upsertEvent(savedEvent);
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(DayzoEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete event?'),
          content: Text('This will remove "${event.title}" from Dayzo on this device.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(backgroundColor: _dayzoOrange),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final originalIndex = _events.indexWhere((storedEvent) => storedEvent.id == event.id);
    setState(() {
      _events.removeWhere((storedEvent) => storedEvent.id == event.id);
    });
    await _saveEvents();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('"${event.title}" deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              setState(() {
                final insertIndex = originalIndex.clamp(0, _events.length).toInt();
                _events.insert(insertIndex, event);
                _events.sort(_compareEvents);
              });
              await _saveEvents();
            },
          ),
        ),
      );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) {
          return SettingsScreen(
            darkMode: widget.darkMode,
            onDarkModeChanged: widget.onDarkModeChanged,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dayzo'),
        actions: [
          Semantics(
            label: 'Open Dayzo settings',
            button: true,
            child: IconButton(
              tooltip: 'Settings',
              onPressed: _openSettings,
              icon: const Icon(Icons.settings_outlined),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        tooltip: 'Add event',
        onPressed: () => _showEventForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add event'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  DayzoHeaderCard(
                    eventCount: _events.length,
                    upcomingCount: _events.where((event) => !event.dateOnly.isBefore(_today)).length,
                  ),
                  const SizedBox(height: 18),
                  if (_events.isEmpty)
                    EmptyEventsState(onAddEvent: () => _showEventForm())
                  else ...[
                    Text(
                      'Upcoming countdowns',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 12),
                    for (final event in _events) ...[
                      DayzoEventCard(
                        event: event,
                        onEdit: () => _showEventForm(event),
                        onDelete: () => _confirmDelete(event),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ],
              ),
      ),
    );
  }
}

class DayzoHeaderCard extends StatelessWidget {
  const DayzoHeaderCard({
    super.key,
    required this.eventCount,
    required this.upcomingCount,
  });

  final int eventCount;
  final int upcomingCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Dayzo summary. $upcomingCount upcoming events. $eventCount total events.',
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_dayzoPurple, _dayzoDeepPurple, _dayzoOrange],
          ),
          boxShadow: [
            BoxShadow(
              color: _dayzoPurple.withValues(alpha: 0.24),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 360;
            final stats = Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _HeaderStat(label: 'Upcoming', value: upcomingCount.toString()),
                _HeaderStat(label: 'Total', value: eventCount.toString()),
              ],
            );

            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dayzo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Countdown & Event Tracker',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Keep your milestones close, sorted by the nearest upcoming date.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.35,
                  ),
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  copy,
                  const SizedBox(height: 18),
                  stats,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: copy),
                const SizedBox(width: 16),
                stats,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyEventsState extends StatelessWidget {
  const EmptyEventsState({
    super.key,
    required this.onAddEvent,
  });

  final VoidCallback onAddEvent;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: _dayzoOrange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.event_available_outlined,
                color: _dayzoOrange,
                size: 38,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No events yet',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a birthday, trip, launch, deadline, or personal milestone. Dayzo stores it only on this device.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAddEvent,
              icon: const Icon(Icons.add),
              label: const Text('Create your first event'),
            ),
          ],
        ),
      ),
    );
  }
}

class DayzoEventCard extends StatelessWidget {
  const DayzoEventCard({
    super.key,
    required this.event,
    required this.onEdit,
    required this.onDelete,
  });

  final DayzoEvent event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final countdown = CountdownInfo.fromDate(event.date);

    return Semantics(
      container: true,
      label: '${event.title}. ${countdown.semanticLabel}. ${formatLongDate(event.date)}.',
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 340;
                final details = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        Text(
                          formatLongDate(event.date),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      countdown.detail,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                );

                final actions = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CountdownBadge(countdown: countdown),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Delete ${event.title}',
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      details,
                      const SizedBox(height: 14),
                      actions,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: details),
                    const SizedBox(width: 12),
                    actions,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class CountdownBadge extends StatelessWidget {
  const CountdownBadge({
    super.key,
    required this.countdown,
  });

  final CountdownInfo countdown;

  @override
  Widget build(BuildContext context) {
    final badgeColor = countdown.isPast ? Colors.grey : _dayzoPurple;
    return Semantics(
      label: countdown.semanticLabel,
      child: Container(
        constraints: const BoxConstraints(minWidth: 76),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              countdown.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: badgeColor,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            Text(
              countdown.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: badgeColor,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EventFormSheet extends StatefulWidget {
  const EventFormSheet({
    super.key,
    required this.onSave,
    this.event,
  });

  final DayzoEvent? event;
  final Future<void> Function(String title, DateTime date) onSave;

  @override
  State<EventFormSheet> createState() => _EventFormSheetState();
}

class _EventFormSheetState extends State<EventFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  DateTime? _selectedDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event?.title ?? '');
    _selectedDate = widget.event?.date;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(FormFieldState<DateTime> field) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentDate = _selectedDate ?? today;
    final firstDate = currentDate.isBefore(today) ? currentDate : today;

    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate.isBefore(firstDate) ? firstDate : currentDate,
      firstDate: firstDate,
      lastDate: DateTime(today.year + 10, today.month, today.day),
      helpText: 'Select event date',
    );

    if (picked == null) {
      return;
    }

    final dateOnly = DateTime(picked.year, picked.month, picked.day);
    setState(() {
      _selectedDate = dateOnly;
    });
    field.didChange(dateOnly);
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate() || _selectedDate == null) {
      return;
    }

    setState(() {
      _saving = true;
    });

    await widget.onSave(_titleController.text.trim(), _selectedDate!);

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding + 20),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.event == null ? 'Add event' : 'Edit event',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Event title',
                  hintText: 'Example: Product launch',
                  prefixIcon: Icon(Icons.celebration_outlined),
                ),
                validator: (value) {
                  final title = value?.trim() ?? '';
                  if (title.isEmpty) {
                    return 'Enter an event title';
                  }
                  if (title.length < 2) {
                    return 'Title must be at least 2 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              FormField<DateTime>(
                initialValue: _selectedDate,
                validator: (value) {
                  if (value == null) {
                    return 'Choose a date';
                  }
                  return null;
                },
                builder: (field) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _pickDate(field),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Event date',
                        errorText: field.errorText,
                        prefixIcon: const Icon(Icons.calendar_month_outlined),
                        suffixIcon: const Icon(Icons.arrow_drop_down),
                      ),
                      child: Text(
                        _selectedDate == null ? 'Select a date' : formatLongDate(_selectedDate!),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(_saving ? 'Saving...' : 'Save event'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.darkMode,
    required this.onDarkModeChanged,
  });

  final bool darkMode;
  final ValueChanged<bool> onDarkModeChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Card(
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    value: darkMode,
                    onChanged: onDarkModeChanged,
                    secondary: const Icon(Icons.dark_mode_outlined),
                    title: const Text('Dark mode'),
                    subtitle: const Text('Your theme choice is saved on this device.'),
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('App version'),
                    subtitle: Text('Version $_appVersion ($_appBuild)'),
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(Icons.storage_outlined),
                    title: Text('Storage'),
                    subtitle: Text('Events and settings stay in local device storage only.'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Privacy Policy'),
                    subtitle: const Text('How Dayzo handles local-only data.'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (context) => const LegalScreen(
                          title: 'Privacy Policy',
                          sections: privacyPolicySections,
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Terms & Conditions'),
                    subtitle: const Text('Usage terms for Dayzo.'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (context) => const LegalScreen(
                          title: 'Terms & Conditions',
                          sections: termsSections,
                        ),
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

class LegalScreen extends StatelessWidget {
  const LegalScreen({
    super.key,
    required this.title,
    required this.sections,
  });

  final String title;
  final List<LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dayzo - Countdown & Event Tracker',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: _dayzoPurple,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Last Updated: $_lastUpdated'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (final section in sections) ...[
              LegalSectionCard(section: section),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class LegalSectionCard extends StatelessWidget {
  const LegalSectionCard({
    super.key,
    required this.section,
  });

  final LegalSection section;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 10),
            for (final paragraph in section.paragraphs) ...[
              Text(
                paragraph,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class LegalSection {
  const LegalSection(this.title, this.paragraphs);

  final String title;
  final List<String> paragraphs;
}

class CountdownInfo {
  const CountdownInfo({
    required this.label,
    required this.caption,
    required this.detail,
    required this.semanticLabel,
    required this.isPast,
  });

  final String label;
  final String caption;
  final String detail;
  final String semanticLabel;
  final bool isPast;

  factory CountdownInfo.fromDate(DateTime date, {DateTime? now}) {
    final currentMoment = now ?? DateTime.now();
    final today = DateTime(currentMoment.year, currentMoment.month, currentMoment.day);
    final targetDate = DateTime(date.year, date.month, date.day);
    final calendarDays = targetDate.difference(today).inDays;

    if (calendarDays < 0) {
      final daysAgo = calendarDays.abs();
      return CountdownInfo(
        label: 'Done',
        caption: 'Past',
        detail: daysAgo == 1 ? 'Completed 1 day ago' : 'Completed $daysAgo days ago',
        semanticLabel: daysAgo == 1 ? 'Completed 1 day ago' : 'Completed $daysAgo days ago',
        isPast: true,
      );
    }

    if (calendarDays == 0) {
      return const CountdownInfo(
        label: 'Today',
        caption: 'Now',
        detail: 'Happening today',
        semanticLabel: 'Happening today',
        isPast: false,
      );
    }

    final exactRemaining = targetDate.difference(currentMoment);
    final detail = exactRemaining.isNegative ? 'Starts soon' : 'Starts in ${formatDuration(exactRemaining)}';
    final dayLabel = calendarDays == 1 ? '1 day' : '$calendarDays days';

    return CountdownInfo(
      label: calendarDays.toString(),
      caption: calendarDays == 1 ? 'day' : 'days',
      detail: detail,
      semanticLabel: '$dayLabel remaining',
      isPast: false,
    );
  }
}

String formatDuration(Duration duration) {
  if (duration.inDays >= 1) {
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    if (hours == 0) {
      return days == 1 ? '1 day' : '$days days';
    }
    final dayLabel = days == 1 ? '1 day' : '$days days';
    final hourLabel = hours == 1 ? '1 hour' : '$hours hours';
    return '$dayLabel, $hourLabel';
  }

  if (duration.inHours >= 1) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (minutes == 0) {
      return hours == 1 ? '1 hour' : '$hours hours';
    }
    final hourLabel = hours == 1 ? '1 hour' : '$hours hours';
    final minuteLabel = minutes == 1 ? '1 minute' : '$minutes minutes';
    return '$hourLabel, $minuteLabel';
  }

  if (duration.inMinutes >= 1) {
    final minutes = duration.inMinutes;
    return minutes == 1 ? '1 minute' : '$minutes minutes';
  }

  return 'less than a minute';
}

String formatLongDate(DateTime date) {
  return '${_weekdayNames[date.weekday - 1]}, ${_monthNames[date.month - 1]} ${date.day}, ${date.year}';
}

const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _monthNames = [
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

const privacyPolicySections = [
  LegalSection('Introduction', [
    'Dayzo - Countdown & Event Tracker is designed to help you create simple countdowns for dates that matter to you. This Privacy Policy explains how the app handles information in a clear, practical way.',
    'Dayzo is intentionally local-first. The app does not require an account, does not connect to a Dayzo backend, and does not use Firebase, analytics, advertising networks, notifications, or login services.',
  ]),
  LegalSection('Information We Store', [
    'Dayzo stores the event titles and event dates that you choose to create inside the app. It also stores your dark mode preference so the app can reopen using the same appearance you selected.',
    'This information is stored for app functionality only. Dayzo uses it to display your countdown list, sort events by date, calculate countdown status, and keep your chosen theme preference.',
  ]),
  LegalSection('Local Device Storage', [
    'All Dayzo event data is saved using local device storage through SharedPreferences. The data remains on the device where you created it unless you remove the app, clear the app data, or transfer device data through operating-system tools outside of Dayzo.',
    'Dayzo does not provide cloud sync, remote backup, server processing, or a web account. If you change devices, Dayzo does not automatically copy your events to another device.',
  ]),
  LegalSection('No Account Required', [
    'You can use Dayzo without creating a username, password, profile, or account. Dayzo does not ask you to sign in and does not associate your events with an online identity.',
    'Because no account exists, Dayzo cannot recover events that are deleted from your device or lost when local device storage is cleared.',
  ]),
  LegalSection('No Personal Data Collection', [
    'Dayzo does not intentionally collect personal data from you. The app does not request your name, email address, phone number, location, contacts, photos, calendar, microphone, camera, or similar personal information.',
    'Event titles are written by you and may include personal wording if you choose to enter it. That content remains local to your device and is not collected by Dayzo.',
  ]),
  LegalSection('No Analytics', [
    'Dayzo does not include analytics SDKs or behavioral tracking tools. We do not track screens viewed, buttons tapped, sessions, device identifiers, advertising identifiers, retention, or usage funnels.',
    'No analytics events are sent from Dayzo because the app has no analytics service configured.',
  ]),
  LegalSection('No Advertising Networks', [
    'Dayzo does not show ads and does not include advertising network SDKs. The app does not create advertising profiles, request ad identifiers, or share event data for ad targeting.',
  ]),
  LegalSection('No Third-Party Sharing', [
    'Dayzo does not sell, rent, disclose, or share your event information with third parties. The app has no backend service that receives your event titles, dates, or theme settings.',
    'Some app stores or operating systems may process download, crash, purchase, or platform-level diagnostic information under their own policies. That information is handled by those platforms, not by Dayzo inside the app.',
  ]),
  LegalSection('Data Security', [
    'Dayzo reduces privacy risk by keeping app data local and avoiding unnecessary network services. Local storage is protected by the security controls of your device and operating system.',
    'You are responsible for protecting access to your device. If someone can unlock or access your device, they may be able to view the events stored in Dayzo.',
  ]),
  LegalSection("Children's Privacy", [
    'Dayzo is a general productivity app and is not directed to children. The app does not knowingly collect personal information from children or any other users.',
    'Because Dayzo does not use accounts, analytics, ads, or a backend, it does not knowingly transmit children\'s personal information to Dayzo-controlled services.',
  ]),
  LegalSection('User Control of Data', [
    'You control the event titles and dates you add to Dayzo. You can edit events, delete individual events, and undo a deletion immediately when the undo option is shown.',
    'You can also control the app appearance by turning dark mode on or off in Settings. That preference is stored locally and can be changed at any time.',
  ]),
  LegalSection('Data Deletion', [
    'You can delete an event from the main event list. After confirming deletion, Dayzo removes the event from local storage. If you use the undo action immediately, Dayzo restores the event locally.',
    'You may also delete Dayzo data through your device settings by clearing app data or uninstalling the app. These operating-system actions may remove all locally stored Dayzo events and preferences.',
  ]),
  LegalSection('Changes to Policy', [
    'We may update this Privacy Policy to reflect improvements, legal requirements, or changes to Dayzo. Any update should continue to describe the app accurately and clearly.',
    'If Dayzo ever introduces features that materially change how data is handled, the policy should be updated before or alongside that release.',
  ]),
  LegalSection('Contact Information', [
    'If you have questions about this Privacy Policy or Dayzo\'s local-only data practices, contact the Dayzo team through the support or developer contact listed on the app store page or project website.',
  ]),
];

const termsSections = [
  LegalSection('Acceptance of Terms', [
    'By downloading, opening, or using Dayzo - Countdown & Event Tracker, you agree to these Terms & Conditions. If you do not agree with these terms, do not use the app.',
    'These terms apply to your use of Dayzo as a local countdown and event tracking tool.',
  ]),
  LegalSection('Description of Service', [
    'Dayzo helps you create event countdowns by entering an event title and date. The app stores events locally on your device, sorts them by the nearest upcoming date, and displays countdown information.',
    'Dayzo does not provide a backend service, account system, Firebase integration, login, advertising, analytics, notifications, cloud sync, or remote storage.',
  ]),
  LegalSection('User Responsibilities', [
    'You are responsible for the event titles and dates you enter. You should only enter information that you are comfortable storing on your device.',
    'You are responsible for maintaining access to your device and for backing up device data if you want to preserve local app information outside of Dayzo.',
  ]),
  LegalSection('Event Accuracy Disclaimer', [
    'Dayzo displays event information based on the title and date you provide. The app cannot verify whether an event title is correct, whether a date is accurate, or whether plans outside the app have changed.',
    'You should confirm important dates independently, especially for travel, financial, legal, medical, academic, professional, or time-sensitive commitments.',
  ]),
  LegalSection('Countdown Accuracy', [
    'Dayzo calculates countdowns using the date stored on your device and the current date and time reported by your device. Countdown values can be affected by device clock settings, time zone changes, daylight saving transitions, and operating-system behavior.',
    'Dayzo is intended as a helpful planning display, not as a guaranteed timing authority. For critical deadlines, use official calendars, reminders, or other authoritative tools in addition to Dayzo.',
  ]),
  LegalSection('Intellectual Property', [
    'Dayzo, including its name, app design, branding, color identity, interface elements, and related materials, is owned by its respective developer or rights holder unless otherwise stated.',
    'You may use the app for personal countdown and event tracking. You may not copy, resell, redistribute, or misuse Dayzo branding or app materials except where permitted by applicable law or written permission.',
  ]),
  LegalSection('Limitation of Liability', [
    'Dayzo is provided as a simple productivity tool. To the fullest extent permitted by law, Dayzo and its developers are not liable for missed events, incorrect dates, lost local data, device issues, indirect damages, incidental damages, or consequential losses arising from use of the app.',
    'Some jurisdictions do not allow certain limitations of liability, so some limitations may not apply to you. In those cases, liability is limited to the maximum extent permitted by applicable law.',
  ]),
  LegalSection('App Availability', [
    'Dayzo may be updated, interrupted, removed from distribution, or changed over time. Local app functionality may depend on your device, operating system version, available storage, and platform compatibility.',
    'The app does not guarantee continuous availability on every device or operating system version.',
  ]),
  LegalSection('Updates and Changes', [
    'Dayzo may receive updates that improve reliability, accessibility, content, compatibility, or user experience. Updates may change app behavior while preserving the core purpose of local countdown and event tracking.',
    'These Terms & Conditions may also be updated when needed. Continued use of Dayzo after updates means you accept the revised terms.',
  ]),
  LegalSection('Termination of Use', [
    'You may stop using Dayzo at any time by deleting the app from your device. You may also remove individual events from inside the app.',
    'Because Dayzo does not use accounts, there is no Dayzo account to close and no server-side profile to delete.',
  ]),
  LegalSection('Governing Terms', [
    'These terms are intended to be interpreted consistently with applicable laws and platform requirements. If any part of these terms is found unenforceable, the remaining sections should continue to apply.',
    'Use of Dayzo may also be subject to app store terms, device platform terms, and open-source license terms where applicable.',
  ]),
  LegalSection('Contact Information', [
    'If you have questions about these Terms & Conditions, contact the Dayzo team through the support or developer contact listed on the app store page or project website.',
  ]),
];
