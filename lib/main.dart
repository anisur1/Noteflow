import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  final androidImpl =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  await androidImpl?.requestNotificationsPermission();
  await androidImpl?.requestExactAlarmsPermission();

  runApp(const ProductivityApp());
}

class ProductivityApp extends StatefulWidget {
  const ProductivityApp({super.key});

  @override
  State<ProductivityApp> createState() => _ProductivityAppState();
}

class _ProductivityAppState extends State<ProductivityApp> {
  bool isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NoteFlow Pro',
      debugShowCheckedModeBanner: false,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      home: HomeScreen(
        isDarkMode: isDarkMode,
        onThemeChanged: (val) => setState(() => isDarkMode = val),
      ),
    );
  }
}

class WorkspaceItem {
  String id;
  String title;
  String content;
  bool isTask;
  bool isCompleted;
  String priority;
  int colorIndex;
  String? imagePath;
  DateTime? reminderDate;
  bool isPinned;
  List> checklist;

  WorkspaceItem({
    required this.id,
    required this.title,
    required this.content,
    this.isTask = false,
    this.isCompleted = false,
    this.priority = 'Medium',
    this.colorIndex = 0,
    this.imagePath,
    this.reminderDate,
    this.isPinned = false,
    this.checklist = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'isTask': isTask,
        'isCompleted': isCompleted,
        'priority': priority,
        'colorIndex': colorIndex,
        'imagePath': imagePath,
        'reminderDate': reminderDate?.toIso8601String(),
        'isPinned': isPinned,
        'checklist': checklist,
      };

  factory WorkspaceItem.fromJson(Map<String, dynamic> json) => WorkspaceItem(
        id: json['id'],
        title: json['title'],
        content: json['content'],
        isTask: json['isTask'] ?? false,
        isCompleted: json['isCompleted'] ?? false,
        priority: json['priority'] ?? 'Medium',
        colorIndex: json['colorIndex'] ?? 0,
        imagePath: json['imagePath'],
        reminderDate: json['reminderDate'] != null
            ? DateTime.parse(json['reminderDate'])
            : null,
        isPinned: json['isPinned'] ?? false,
        checklist: List>.from(json['checklist'] ?? []),
      );
}

final List<Color> noteColorsLight = [
  Colors.white,
  const Color(0xFFF28B82),
  const Color(0xFFFBBC04),
  const Color(0xFFFFF475),
  const Color(0xFFCCFF90),
  const Color(0xFFA7FFEB),
  const Color(0xFFCBF0F8),
  const Color(0xFFD7AEFB),
  const Color(0xFFFDCFE8),
];

final List<Color> noteColorsDark = [
  const Color(0xFF1E1E1E),
  const Color(0xFF5C2B29),
  const Color(0xFF614A19),
  const Color(0xFF635D19),
  const Color(0xFF345920),
  const Color(0xFF16504B),
  const Color(0xFF2D555E),
  const Color(0xFF42275E),
  const Color(0xFF5B2245),
];

class HomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onThemeChanged;

  const HomeScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<WorkspaceItem> items = [];
  int currentTab = 0;
  bool isGridView = true;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('workspace_items');
    if (data != null) {
      final List decoded = jsonDecode(data);
      setState(() {
        items = decoded.map((e) => WorkspaceItem.fromJson(e)).toList();
      });
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString('workspace_items', encoded);
  }

  Future<void> _scheduleNotification(WorkspaceItem item) async {
    if (item.reminderDate == null) return;
    if (item.reminderDate!.isBefore(DateTime.now())) return;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'noteflow_reminders_id',
      'NoteFlow Reminders',
      channelDescription: 'Background notifications for scheduled tasks',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      item.id.hashCode,
      item.isTask
          ? 'টাস্ক রিমাইন্ডার: ${item.title.isEmpty ? "টাস্ক" : item.title}'
          : 'নোট রিমাইন্ডার: ${item.title.isEmpty ? "নোট" : item.title}',
      item.content.isNotEmpty ? item.content : 'আপনার নির্ধারিত ডেডলাইন চলে এসেছে!',
      tz.TZDateTime.from(item.reminderDate!, tz.local),
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  void _openEditor({WorkspaceItem? existingItem, bool defaultIsTask = false}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ItemEditorScreen(
          item: existingItem,
          defaultIsTask: defaultIsTask,
          isDarkMode: widget.isDarkMode,
        ),
      ),
    );

    if (result != null && result is WorkspaceItem) {
      setState(() {
        final index = items.indexWhere((element) => element.id == result.id);
        if (index >= 0) {
          items[index] = result;
        } else {
          items.insert(0, result);
        }
      });
      _saveData();
      _scheduleNotification(result);
    } else if (result == 'DELETE' && existingItem != null) {
      setState(() {
        items.removeWhere((element) => element.id == existingItem.id);
      });
      _saveData();
    }
  }

  @override
  Widget build(BuildContext context) {
    List<WorkspaceItem> filteredItems = items.where((item) {
      final matchesSearch =
          item.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
              item.content.toLowerCase().contains(searchQuery.toLowerCase());
      if (!matchesSearch) return false;
      if (currentTab == 1) return item.isTask;
      if (currentTab == 2) return item.reminderDate != null;
      return true;
    }).toList();

    filteredItems.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return 0;
    });

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          decoration: const InputDecoration(
            hintText: 'নোট বা টাস্ক খুঁজুন...',
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (val) => setState(() => searchQuery = val),
        ),
        actions: [
          IconButton(
            icon: Icon(isGridView ? Icons.view_agenda_outlined : Icons.grid_view),
            onPressed: () => setState(() => isGridView = !isGridView),
          ),
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => widget.onThemeChanged(!widget.isDarkMode),
          ),
        ],
      ),
      body: filteredItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.dashboard_customize_outlined,
                      size: 64, color: Colors.grey.withOpacity(0.5)),
                  const SizedBox(height: 12),
                  const Text('কোনো নোট বা টাস্ক নেই। নিচে + বাটনে ট্যাপ করুন!'),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(8.0),
              child: isGridView
                  ? GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) =>
                          _buildCard(filteredItems[index]),
                    )
                  : ListView.builder(
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) =>
                          _buildCard(filteredItems[index]),
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(defaultIsTask: currentTab == 1),
        icon: const Icon(Icons.add),
        label: Text(currentTab == 1 ? 'নতুন টাস্ক' : 'নতুন নোট'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentTab,
        onDestinationSelected: (idx) => setState(() => currentTab = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.notes), label: 'সব নোট'),
          NavigationDestination(
              icon: Icon(Icons.check_circle_outline), label: 'টাস্কসমূহ'),
          NavigationDestination(
              icon: Icon(Icons.notifications_active_outlined),
              label: 'রিমাইন্ডার'),
        ],
      ),
    );
  }

  Widget _buildCard(WorkspaceItem item) {
    final bgColor = widget.isDarkMode
        ? noteColorsDark[item.colorIndex]
        : noteColorsLight[item.colorIndex];

    return GestureDetector(
      onTap: () => _openEditor(existingItem: item),
      child: Card(
        color: bgColor,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (item.isTask)
                    Checkbox(
                      value: item.isCompleted,
                      onChanged: (val) {
                        setState(() => item.isCompleted = val ?? false);
                        _saveData();
                      },
                    ),
                  Expanded(
                    child: Text(
                      item.title.isEmpty ? '(শিরোনামহীন)' : item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        decoration: item.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                  if (item.isPinned)
                    const Icon(Icons.push_pin, size: 16, color: Colors.orange),
                ],
              ),
              if (item.imagePath != null && File(item.imagePath!).existsSync())
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(item.imagePath!),
                      height: 75,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  item.content,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    decoration:
                        item.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (item.isTask)
                    Chip(
                      label: Text(item.priority,
                          style: const TextStyle(fontSize: 10)),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                  if (item.reminderDate != null)
                    Chip(
                      avatar: const Icon(Icons.alarm, size: 12),
                      label: Text(
                        DateFormat('dd MMM, hh:mm a').format(item.reminderDate!),
                        style: const TextStyle(fontSize: 10),
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ItemEditorScreen extends StatefulWidget {
  final WorkspaceItem? item;
  final bool defaultIsTask;
  final bool isDarkMode;

  const ItemEditorScreen({
    super.key,
    this.item,
    required this.defaultIsTask,
    required this.isDarkMode,
  });

  @override
  State<ItemEditorScreen> createState() => _ItemEditorScreenState();
}

class _ItemEditorScreenState extends State<ItemEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  final TextEditingController _subtaskController = TextEditingController();

  late bool isTask;
  late bool isPinned;
  late String priority;
  late int colorIndex;
  String? imagePath;
  DateTime? reminderDate;
  List> checklist = [];

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _titleController = TextEditingController(text: item?.title ?? '');
    _contentController = TextEditingController(text: item?.content ?? '');
    isTask = item?.isTask ?? widget.defaultIsTask;
    isPinned = item?.isPinned ?? false;
    priority = item?.priority ?? 'Medium';
    colorIndex = item?.colorIndex ?? 0;
    imagePath = item?.imagePath;
    reminderDate = item?.reminderDate;
    checklist = List>.from(item?.checklist ?? []);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => imagePath = picked.path);
    }
  }

  Future<void> _pickReminderDateTime() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: reminderDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (date == null) return;

    if (!mounted) return;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(reminderDate ?? DateTime.now()),
    );
    if (time == null) return;

    setState(() {
      reminderDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _saveItem() {
    final newItem = WorkspaceItem(
      id: widget.item?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      isTask: isTask,
      isCompleted: widget.item?.isCompleted ?? false,
      priority: priority,
      colorIndex: colorIndex,
      imagePath: imagePath,
      reminderDate: reminderDate,
      isPinned: isPinned,
      checklist: checklist,
    );
    Navigator.pop(context, newItem);
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDarkMode
        ? noteColorsDark[colorIndex]
        : noteColorsLight[colorIndex];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        actions: [
          IconButton(
            icon: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined),
            onPressed: () => setState(() => isPinned = !isPinned),
          ),
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            onPressed: _pickImage,
          ),
          IconButton(
            icon: const Icon(Icons.add_alert_outlined),
            onPressed: _pickReminderDateTime,
          ),
          if (widget.item != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () => Navigator.pop(context, 'DELETE'),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilledButton.icon(
              onPressed: _saveItem,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('সেভ'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FilterChip(
                  label: const Text('টাস্ক মোড (Notion Style)'),
                  selected: isTask,
                  onSelected: (val) => setState(() => isTask = val),
                ),
                const SizedBox(width: 10),
                if (isTask)
                  DropdownButton<String>(
                    value: priority,
                    items: ['High', 'Medium', 'Low']
                        .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text('Priority: $p'),
                            ))
                        .toList(),
                    onChanged: (val) =>
                        setState(() => priority = val ?? 'Medium'),
                  ),
              ],
            ),
            if (reminderDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: InputChip(
                  avatar: const Icon(Icons.alarm, size: 16),
                  label: Text(
                      'রিমাইন্ডার: ${DateFormat('dd MMM yyyy, hh:mm a').format(reminderDate!)}'),
                  onDeleted: () => setState(() => reminderDate = null),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: 'শিরোনাম লিখুন...',
                border: InputBorder.none,
              ),
            ),
            if (imagePath != null && File(imagePath!).existsSync())
              Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(imagePath!), fit: BoxFit.cover),
                  ),
                  IconButton.filled(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => imagePath = null),
                  ),
                ],
              ),
            const Divider(),
            TextField(
              controller: _contentController,
              maxLines: null,
              minLines: 5,
              style: const TextStyle(fontSize: 16),
              decoration: const InputDecoration(
                hintText: 'আপনার নোট বা বিস্তারিত তথ্য এখানে লিখুন...',
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 16),
            const Text('সাব-টাস্ক / চেকলিস্ট:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            ...checklist.asMap().entries.map((entry) {
              int idx = entry.key;
              var sub = entry.value;
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  sub['title'],
                  style: TextStyle(
                    decoration: sub['done'] == true
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                value: sub['done'] ?? false,
                onChanged: (val) =>
                    setState(() => checklist[idx]['done'] = val),
                secondary: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => checklist.removeAt(idx)),
                ),
              );
            }),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subtaskController,
                    decoration: const InputDecoration(
                      hintText: '+ নতুন চেকলিস্ট আইটেম যোগ করুন...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () {
                    if (_subtaskController.text.trim().isNotEmpty) {
                      setState(() {
                        checklist.add({
                          'title': _subtaskController.text.trim(),
                          'done': false,
                        });
                        _subtaskController.clear();
                      });
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: noteColorsLight.length,
          itemBuilder: (context, idx) {
            final c = widget.isDarkMode
                ? noteColorsDark[idx]
                : noteColorsLight[idx];
            return GestureDetector(
              onTap: () => setState(() => colorIndex = idx),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorIndex == idx ? Colors.blueAccent : Colors.grey,
                    width: colorIndex == idx ? 3 : 1,
                  ),
                ),
                child: colorIndex == idx
                    ? const Icon(Icons.check, size: 18)
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }
}
