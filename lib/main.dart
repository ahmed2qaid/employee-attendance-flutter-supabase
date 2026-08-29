import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    publishableKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2563EB),
      brightness: Brightness.light,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
            side: BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(13)),
            borderSide: BorderSide(color: Color(0xFFCBD5E1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(13)),
            borderSide: BorderSide(color: Color(0xFFCBD5E1)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(110, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(105, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: AttendancePage(),
      ),
    );
  }
}

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final employee = TextEditingController();
  DateTime start = DateTime(2026, 7, 26);
  DateTime end = DateTime(2026, 8, 25);
  DateTime rotationStart = DateTime(2026, 7, 26);
  final Map<String, TimeOfDay?> ins = {};
  final Map<String, TimeOfDay?> outs = {};
  String shiftMode = 'single';
  String shiftOne = 'morning';
  String shiftTwo = 'evening';
  String message = '';
  int lateGrace = 15;
  int earlyGrace = 5;

  String key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<DateTime> get dates {
    final result = <DateTime>[];
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      result.add(d);
    }
    return result;
  }

  int tmin(TimeOfDay? t) => t == null ? 0 : t.hour * 60 + t.minute;

  int worked(TimeOfDay? a, TimeOfDay? b) {
    if (a == null || b == null) return 0;
    var x = tmin(a);
    var y = tmin(b);
    if (y <= x) y += 1440;
    return y - x;
  }

  String shiftFor(DateTime d) {
    if (shiftMode != 'dual') return shiftOne;
    final diff = d.difference(rotationStart).inDays;
    final week = (diff / 7).floor();
    return (((week % 2) + 2) % 2) == 0 ? shiftOne : shiftTwo;
  }

  Map<String, int> analyze(DateTime d) {
    if (d.weekday == DateTime.friday) {
      return {'worked': 0, 'late': 0, 'early': 0, 'overtime': 0, 'status': 0};
    }
    final i = ins[key(d)];
    final o = outs[key(d)];
    if (i == null && o == null) {
      return {'worked': 0, 'late': 0, 'early': 0, 'overtime': 0, 'status': 1};
    }
    if (i == null || o == null) {
      return {'worked': 0, 'late': 0, 'early': 0, 'overtime': 0, 'status': 2};
    }
    final m = worked(i, o);
    final s = shiftFor(d);
    final si = s == 'morning' ? 360 : 840;
    final so = s == 'morning' ? 840 : 1320;
    var ai = tmin(i);
    var ao = tmin(o);
    if (ao <= ai) ao += 1440;
    final rawLate = (ai - si).clamp(0, 9999).toInt();
    final rawEarly = (so - ao).clamp(0, 9999).toInt();
    final overtime = (ao - so).clamp(0, 9999).toInt();
    return {
      'worked': m,
      'late': rawLate > lateGrace ? rawLate : 0,
      'early': rawEarly > earlyGrace ? rawEarly : 0,
      'overtime': overtime,
      'status': 3,
    };
  }

  int get total => dates.fold(0, (s, d) => s + analyze(d)['worked']!);
  int get totalLate => dates.fold(0, (s, d) => s + analyze(d)['late']!);
  int get totalEarly => dates.fold(0, (s, d) => s + analyze(d)['early']!);
  int get totalOvertime => dates.fold(0, (s, d) => s + analyze(d)['overtime']!);
  int get absent => dates.where((d) => analyze(d)['status'] == 1).length;
  int get pending => dates.where((d) => analyze(d)['status'] == 2).length;

  String fmt(TimeOfDay? t) => t == null
      ? ''
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  String durationText(int minutes) => '${minutes ~/ 60}س ${minutes % 60}د';

  Future<void> pick(DateTime d, bool entry) async {
    final s = shiftFor(d);
    final def = s == 'evening'
        ? (entry
            ? const TimeOfDay(hour: 14, minute: 0)
            : const TimeOfDay(hour: 22, minute: 0))
        : (entry
            ? const TimeOfDay(hour: 6, minute: 0)
            : const TimeOfDay(hour: 14, minute: 0));
    final t = await showTimePicker(context: context, initialTime: def);
    if (t != null) {
      setState(() => entry ? ins[key(d)] = t : outs[key(d)] = t);
    }
  }

  Future<void> load() async {
    if (employee.text.trim().isEmpty) {
      setState(() => message = 'اكتب اسم الموظف أولًا');
      return;
    }
    final db = Supabase.instance.client;
    final g = await db.from('app_settings').select().eq('id', 1).maybeSingle();
    final p = await db
        .from('employee_policies')
        .select()
        .eq('employee_name', employee.text.trim())
        .maybeSingle();
    final a = await db
        .from('attendances')
        .select()
        .eq('employee_name', employee.text.trim())
        .gte('work_date', key(start))
        .lte('work_date', key(end));
    setState(() {
      lateGrace = (g?['default_late_grace'] ?? 15) as int;
      earlyGrace = (g?['default_early_grace'] ?? 5) as int;
      shiftMode = (p?['shift_mode'] ?? 'single') as String;
      shiftOne = (p?['shift_one'] ?? 'morning') as String;
      shiftTwo = (p?['shift_two'] ?? 'evening') as String;
      rotationStart = DateTime.tryParse(p?['rotation_start']?.toString() ?? '') ?? start;
      ins.clear();
      outs.clear();
      for (final r in a) {
        final d = DateTime.parse(r['work_date']);
        if (r['check_in'] != null) {
          final x = r['check_in'].toString().split(':');
          ins[key(d)] = TimeOfDay(hour: int.parse(x[0]), minute: int.parse(x[1]));
        }
        if (r['check_out'] != null) {
          final x = r['check_out'].toString().split(':');
          outs[key(d)] = TimeOfDay(hour: int.parse(x[0]), minute: int.parse(x[1]));
        }
      }
      message = 'تم تحميل البيانات والورديات';
    });
  }

  Future<void> save() async {
    if (employee.text.trim().isEmpty) {
      setState(() => message = 'اكتب اسم الموظف أولًا');
      return;
    }
    final db = Supabase.instance.client;
    await db.from('app_settings').upsert({
      'id': 1,
      'default_late_grace': lateGrace,
      'default_early_grace': earlyGrace,
    });
    await db.from('employee_policies').upsert({
      'employee_name': employee.text.trim(),
      'shift_mode': shiftMode,
      'shift_one': shiftOne,
      'shift_two': shiftTwo,
      'rotation_start': key(rotationStart),
    }, onConflict: 'employee_name');
    final rows = dates
        .where((d) => d.weekday != DateTime.friday)
        .where((d) => ins[key(d)] != null || outs[key(d)] != null)
        .map((d) => {
              'employee_name': employee.text.trim(),
              'work_date': key(d),
              'check_in': ins[key(d)] == null ? null : fmt(ins[key(d)]),
              'check_out': outs[key(d)] == null ? null : fmt(outs[key(d)]),
            })
        .toList();
    if (rows.isNotEmpty) {
      await db.from('attendances').upsert(rows, onConflict: 'employee_name,work_date');
    }
    setState(() => message = 'تم حفظ الدوام والورديات');
  }

  Future<void> pickDate(bool isStart) async {
    final current = isStart ? start : end;
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: current,
    );
    if (d != null) setState(() => isStart ? start = d : end = d);
  }

  Widget fieldBox({required String label, required Widget child}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 210, maxWidth: 330),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF334155))),
          const SizedBox(height: 7),
          child,
        ],
      ),
    );
  }

  Widget statCard(String label, String value, IconData icon, Color accent) {
    return Container(
      width: 190,
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x0D0F172A), blurRadius: 22, offset: Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: accent.withValues(alpha: .09), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: accent, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget attendanceCard(DateTime d) {
    final friday = d.weekday == DateTime.friday;
    final a = analyze(d);
    final s = shiftFor(d);
    final status = a['status'] == 1 ? 'غياب' : a['status'] == 2 ? 'معلق' : 'حضور';
    final statusColor = a['status'] == 1
        ? const Color(0xFFDC2626)
        : a['status'] == 2
            ? const Color(0xFFD97706)
            : const Color(0xFF15803D);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: LayoutBuilder(
          builder: (context, c) {
            final compact = c.maxWidth < 760;
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(key(d), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                    const SizedBox(width: 8),
                    if (friday)
                      const _Badge(text: 'إجازة الجمعة', color: Color(0xFF64748B))
                    else
                      _Badge(text: status, color: statusColor),
                  ],
                ),
                const SizedBox(height: 6),
                if (!friday)
                  Text(
                    '${s == 'morning' ? '06:00 – 14:00' : '14:00 – 22:00'}  •  حضور ${durationText(a['worked']!)}  •  إضافي ${durationText(a['overtime']!)}  •  تأخير ${a['late']}د  •  مبكر ${a['early']}د',
                    style: const TextStyle(color: Color(0xFF64748B), height: 1.65, fontSize: 12.5),
                  ),
              ],
            );
            final buttons = friday
                ? const SizedBox.shrink()
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => pick(d, true),
                        icon: const Icon(Icons.login_rounded, size: 18),
                        label: Text(ins[key(d)]?.format(context) ?? 'الحضور'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => pick(d, false),
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: Text(outs[key(d)]?.format(context) ?? 'الانصراف'),
                      ),
                    ],
                  );
            if (compact) {
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [details, if (!friday) const SizedBox(height: 12), buttons]);
            }
            return Row(children: [Expanded(child: details), const SizedBox(width: 16), buttons]);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1460),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 42),
              children: [
                Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [Color(0xFF0F172A), Color(0xFF172554), Color(0xFF2563EB)],
                    ),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: const [BoxShadow(color: Color(0x260F172A), blurRadius: 34, offset: Offset(0, 14))],
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('FLUTTER WEB + SUPABASE', style: TextStyle(color: Color(0xFFBFDBFE), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
                            SizedBox(height: 7),
                            Text('نظام حساب دوام الموظفين', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
                            SizedBox(height: 5),
                            Text('إدارة الحضور والورديات المتناوبة والتأخير والانصراف المبكر والوقت الإضافي.', style: TextStyle(color: Color(0xFFDBEAFE), fontSize: 14)),
                          ],
                        ),
                      ),
                      Icon(Icons.schedule_rounded, color: Colors.white, size: 52),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('إعدادات الدوام', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: [
                            fieldBox(
                              label: 'اسم الموظف',
                              child: TextField(controller: employee, decoration: const InputDecoration(hintText: 'اكتب اسم الموظف')),
                            ),
                            fieldBox(
                              label: 'نظام الورديات',
                              child: DropdownButtonFormField<String>(
                                initialValue: shiftMode,
                                items: const [
                                  DropdownMenuItem(value: 'single', child: Text('وردية واحدة')),
                                  DropdownMenuItem(value: 'dual', child: Text('ورديتان كل 7 أيام')),
                                ],
                                onChanged: (v) => setState(() => shiftMode = v!),
                              ),
                            ),
                            fieldBox(
                              label: 'الوردية 1',
                              child: DropdownButtonFormField<String>(
                                initialValue: shiftOne,
                                items: const [
                                  DropdownMenuItem(value: 'morning', child: Text('صباحي 06:00 – 14:00')),
                                  DropdownMenuItem(value: 'evening', child: Text('مسائي 14:00 – 22:00')),
                                ],
                                onChanged: (v) => setState(() => shiftOne = v!),
                              ),
                            ),
                            if (shiftMode == 'dual')
                              fieldBox(
                                label: 'الوردية 2',
                                child: DropdownButtonFormField<String>(
                                  initialValue: shiftTwo,
                                  items: const [
                                    DropdownMenuItem(value: 'morning', child: Text('صباحي 06:00 – 14:00')),
                                    DropdownMenuItem(value: 'evening', child: Text('مسائي 14:00 – 22:00')),
                                  ],
                                  onChanged: (v) => setState(() => shiftTwo = v!),
                                ),
                              ),
                            if (shiftMode == 'dual')
                              fieldBox(
                                label: 'بداية دورة التناوب',
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final d = await showDatePicker(
                                      context: context,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2100),
                                      initialDate: rotationStart,
                                    );
                                    if (d != null) setState(() => rotationStart = d);
                                  },
                                  icon: const Icon(Icons.calendar_month_rounded),
                                  label: Text(key(rotationStart)),
                                ),
                              ),
                            fieldBox(
                              label: 'سماح التأخير للجميع',
                              child: TextFormField(
                                initialValue: '$lateGrace',
                                keyboardType: TextInputType.number,
                                onChanged: (v) => setState(() => lateGrace = int.tryParse(v) ?? 0),
                              ),
                            ),
                            fieldBox(
                              label: 'سماح الانصراف المبكر للجميع',
                              child: TextFormField(
                                initialValue: '$earlyGrace',
                                keyboardType: TextInputType.number,
                                onChanged: (v) => setState(() => earlyGrace = int.tryParse(v) ?? 0),
                              ),
                            ),
                            fieldBox(
                              label: 'من تاريخ',
                              child: OutlinedButton.icon(
                                onPressed: () => pickDate(true),
                                icon: const Icon(Icons.event_available_rounded),
                                label: Text(key(start)),
                              ),
                            ),
                            fieldBox(
                              label: 'إلى تاريخ',
                              child: OutlinedButton.icon(
                                onPressed: () => pickDate(false),
                                icon: const Icon(Icons.event_rounded),
                                label: Text(key(end)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton.icon(onPressed: load, icon: const Icon(Icons.cloud_download_rounded), label: const Text('تحميل البيانات')),
                            FilledButton.icon(onPressed: save, icon: const Icon(Icons.save_rounded), label: const Text('حفظ التعديلات')),
                            if (message.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                child: Text(message, style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w700)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, c) {
                    final cardWidth = c.maxWidth < 600 ? c.maxWidth : c.maxWidth < 1000 ? (c.maxWidth - 12) / 2 : (c.maxWidth - 36) / 4;
                    final data = [
                      ('إجمالي الحضور', durationText(total), Icons.access_time_filled_rounded, const Color(0xFF2563EB)),
                      ('أيام العمل', (total / 480).toStringAsFixed(6), Icons.calendar_view_week_rounded, const Color(0xFF7C3AED)),
                      ('الوقت الإضافي', durationText(totalOvertime), Icons.more_time_rounded, const Color(0xFF15803D)),
                      ('التأخير', '$totalLate د', Icons.timer_off_rounded, const Color(0xFFD97706)),
                      ('الانصراف المبكر', '$totalEarly د', Icons.exit_to_app_rounded, const Color(0xFFF59E0B)),
                      ('الغياب', '$absent', Icons.person_off_rounded, const Color(0xFFDC2626)),
                      ('المعلق', '$pending', Icons.pending_actions_rounded, const Color(0xFF64748B)),
                    ];
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: data.map((x) => SizedBox(width: cardWidth, child: statCard(x.$1, x.$2, x.$3, x.$4))).toList(),
                    );
                  },
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(child: Text('سجل أيام الدوام', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
                    Text('${dates.length} يوم', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 12),
                ...dates.map(attendanceCard),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: .09), borderRadius: BorderRadius.circular(30)),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
    );
  }
}
