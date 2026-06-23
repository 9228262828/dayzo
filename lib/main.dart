import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const DayzoApp());
}

class DayzoApp extends StatefulWidget {
  const DayzoApp({super.key});

  @override
  State<DayzoApp> createState() => _DayzoAppState();
}

class _DayzoAppState extends State<DayzoApp> {
  bool darkMode = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => darkMode = prefs.getBool('darkMode') ?? false);
  }

  Future<void> updateTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', value);
    setState(() => darkMode = value);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dayzo',
      debugShowCheckedModeBanner: false,
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF7C3AED),
        scaffoldBackgroundColor: const Color(0xFFFAF7F2),
        fontFamily: 'Roboto',
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF8B5CF6),
      ),
      home: SplashScreen(onThemeChanged: updateTheme),
    );
  }
}

class EventItem {
  final String title;
  final String type;
  final DateTime date;
  final String note;

  EventItem({
    required this.title,
    required this.type,
    required this.date,
    required this.note,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'type': type,
    'date': date.toIso8601String(),
    'note': note,
  };

  factory EventItem.fromJson(Map<String, dynamic> json) {
    return EventItem(
      title: json['title'] ?? '',
      type: json['type'] ?? 'Custom',
      date: DateTime.parse(json['date']),
      note: json['note'] ?? '',
    );
  }
}

class SplashScreen extends StatelessWidget {
  final Function(bool) onThemeChanged;

  const SplashScreen({
    super.key,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3E8FF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(.12),
                      blurRadius: 32,
                      offset: const Offset(0, 18),
                    )
                  ],
                ),
                child: Image.asset(
                  'assets/logo.png',
                  width: 150,
                  height: 150,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Dayzo',
                style: TextStyle(
                  fontSize: 46,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2E1065),
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Every day counts.',
                style: TextStyle(
                  fontSize: 17,
                  color: Color(0xFF6B5A7A),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            HomeScreen(onThemeChanged: onThemeChanged),
                      ),
                    );
                  },
                  child: const Text(
                    'Start Counting',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;

  const HomeScreen({
    super.key,
    required this.onThemeChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<EventItem> events = [];

  @override
  void initState() {
    super.initState();
    loadEvents();
  }

  Future<void> loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('events');

    if (data != null) {
      final decoded = jsonDecode(data) as List;
      setState(() {
        events = decoded
            .map((e) => EventItem.fromJson(e))
            .where((e) => e.title.trim().isNotEmpty)
            .toList();
      });
    }
  }

  Future<void> saveEvents() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'events',
      jsonEncode(events.map((e) => e.toJson()).toList()),
    );
  }

  int daysLeft(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    return target.difference(today).inDays;
  }

  Future<void> addEvent() async {
    final result = await Navigator.push<EventItem>(
      context,
      MaterialPageRoute(builder: (_) => const AddEventScreen()),
    );

    if (result != null) {
      setState(() {
        events.add(result);
        events.sort((a, b) => a.date.compareTo(b.date));
      });
      saveEvents();
    }
  }

  Future<void> deleteEvent(int index) async {
    final removed = events[index];
    setState(() => events.removeAt(index));
    await saveEvents();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${removed.title} deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() {
              events.insert(index, removed);
              events.sort((a, b) => a.date.compareTo(b.date));
            });
            saveEvents();
          },
        ),
      ),
    );
  }

  IconData iconFor(String type) {
    switch (type) {
      case 'Birthday':
        return Icons.cake_rounded;
      case 'Travel':
        return Icons.flight_takeoff_rounded;
      case 'Exam':
        return Icons.school_rounded;
      case 'Wedding':
        return Icons.favorite_rounded;
      case 'Anniversary':
        return Icons.celebration_rounded;
      default:
        return Icons.event_rounded;
    }
  }

  Color colorFor(String type) {
    switch (type) {
      case 'Birthday':
        return const Color(0xFFF59E0B);
      case 'Travel':
        return const Color(0xFF0EA5E9);
      case 'Exam':
        return const Color(0xFF6366F1);
      case 'Wedding':
        return const Color(0xFFEC4899);
      case 'Anniversary':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF7C3AED);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nextEvent = events.isEmpty ? null : events.first;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addEvent,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Event'),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/logo.png',
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dayzo',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text('Your upcoming moments'),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Settings',
                      icon: const Icon(Icons.settings_rounded),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SettingsScreen(
                              onThemeChanged: widget.onThemeChanged,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E1065),
                    borderRadius: BorderRadius.circular(34),
                  ),
                  child: nextEvent == null
                      ? const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No events yet',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Add your first event and start counting the days.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  )
                      : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Next Event',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        nextEvent.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${daysLeft(nextEvent.date).abs()}',
                            style: const TextStyle(
                              color: Color(0xFFFFC857),
                              fontSize: 58,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              daysLeft(nextEvent.date) >= 0
                                  ? 'days left'
                                  : 'days ago',
                              style:
                              const TextStyle(color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  'All Events',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            if (events.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'Tap New Event to add birthdays, trips, exams, anniversaries, and more.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              SliverList.builder(
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final event = events[index];
                  final left = daysLeft(event.date);
                  final eventColor = colorFor(event.type);

                  return Padding(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                    child: Dismissible(
                      key: ValueKey('${event.title}-${event.date}-$index'),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) async {
                        return await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Delete event?'),
                            content: Text(
                              'Are you sure you want to delete "${event.title}"?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.pop(context, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        ) ??
                            false;
                      },
                      onDismissed: (_) => deleteEvent(index),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 22),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child:
                        const Icon(Icons.delete_rounded, color: Colors.white),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: eventColor.withOpacity(.14),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(iconFor(event.type), color: eventColor),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.title,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('${event.type} • ${event.date.toString().substring(0, 10)}'),
                                  if (event.note.trim().isNotEmpty)
                                    Text(
                                      event.note,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                Text(
                                  '${left.abs()}',
                                  style: TextStyle(
                                    color: eventColor,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(left >= 0 ? 'left' : 'ago'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 90)),
          ],
        ),
      ),
    );
  }
}

class AddEventScreen extends StatefulWidget {
  const AddEventScreen({super.key});

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final titleController = TextEditingController();
  final noteController = TextEditingController();

  DateTime selectedDate = DateTime.now().add(const Duration(days: 7));
  String selectedType = 'Birthday';

  final types = [
    'Birthday',
    'Travel',
    'Exam',
    'Wedding',
    'Anniversary',
    'Custom',
  ];

  Future<void> pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (date != null) {
      setState(() => selectedDate = date);
    }
  }

  void save() {
    final title = titleController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter event title')),
      );
      return;
    }

    Navigator.pop(
      context,
      EventItem(
        title: title,
        type: selectedType,
        date: selectedDate,
        note: noteController.text.trim(),
      ),
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Event'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Image.asset(
              'assets/logo.png',
              width: 86,
              height: 86,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: titleController,
            decoration: const InputDecoration(
              labelText: 'Event name',
              prefixIcon: Icon(Icons.title_rounded),
              filled: true,
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: selectedType,
            decoration: const InputDecoration(
              labelText: 'Event type',
              prefixIcon: Icon(Icons.category_rounded),
              filled: true,
            ),
            items: types
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => selectedType = v ?? 'Custom'),
          ),
          const SizedBox(height: 14),
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            tileColor: Theme.of(context).cardColor,
            leading: const Icon(Icons.calendar_month_rounded),
            title: const Text('Event date'),
            subtitle: Text(selectedDate.toString().substring(0, 10)),
            trailing: const Icon(Icons.edit_calendar_rounded),
            onTap: pickDate,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: noteController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Note optional',
              prefixIcon: Icon(Icons.notes_rounded),
              filled: true,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: save,
              child: const Text('Save Event'),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;

  const SettingsScreen({
    super.key,
    required this.onThemeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool darkMode = false;

  @override
  void initState() {
    super.initState();
    loadTheme();
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => darkMode = prefs.getBool('darkMode') ?? false);
  }

  Future<void> changeTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', value);
    setState(() => darkMode = value);
    widget.onThemeChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dayzo Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E8FF),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Row(
              children: [
                Image.asset(
                  'assets/logo.png',
                  width: 70,
                  height: 70,
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Dayzo\nEvery day counts.',
                    style: TextStyle(
                      color: Color(0xFF2E1065),
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 18),
          SwitchListTile(
            value: darkMode,
            onChanged: changeTheme,
            title: const Text('Dark Mode'),
            secondary: const Icon(Icons.dark_mode_rounded),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.privacy_tip_rounded),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.article_rounded),
            title: const Text('Terms & Conditions'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TermsScreen()),
            ),
          ),
          const SizedBox(height: 22),
          const Center(
            child: Text(
              'Version 1.0.0',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TextPage(
      title: 'Privacy Policy',
      text:
      'Dayzo is a simple countdown and event tracking app. The app stores your event names, event dates, event types, optional notes, and app settings locally on your device using local storage. Dayzo does not require account creation, login, backend servers, Firebase, ads, notifications, or third-party data sharing. Your events remain on your device. You can remove stored data by deleting events, clearing app data, or uninstalling the app.',
    );
  }
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TextPage(
      title: 'Terms & Conditions',
      text:
      'By using Dayzo, you agree that the app is provided as a personal event countdown tool only. Dayzo helps you track upcoming or past personal dates such as birthdays, trips, exams, weddings, anniversaries, and custom events. The app is provided as-is without guarantees. Since data is stored locally on your device, you are responsible for keeping your device and local data safe.',
    );
  }
}

class TextPage extends StatelessWidget {
  final String title;
  final String text;

  const TextPage({
    super.key,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              text,
              style: const TextStyle(fontSize: 16, height: 1.7),
            ),
          ),
        ],
      ),
    );
  }
}