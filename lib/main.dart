import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
      seedColor: const Color(0xFF0F766E),
      brightness: Brightness.light,
      surface: const Color(0xFFFFFFFF),
    );
    final textTheme = GoogleFonts.ibmPlexSansArabicTextTheme();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        textTheme: textTheme,
        primaryTextTheme: textTheme,
        scaffoldBackgroundColor: const Color(0xFFF5F5F2),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            side: BorderSide(color: Color(0xFFDFDFD8)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(9)),
            borderSide: BorderSide(color: Color(0xFFCACAC2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(9)),
            borderSide: BorderSide(color: Color(0xFFCACAC2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(9)),
            borderSide: BorderSide(color: Color(0xFF0F766E), width: 1.3),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(105, 42),
            backgroundColor: const Color(0xFF0F766E),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
            textStyle: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(100, 40),
            foregroundColor: const Color(0xFF171717),
            side: const BorderSide(color: Color(0xFFCACAC2)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
            textStyle: GoogleFonts.ibmPlexSansArabic(fontWeight: FontWeight.w700),
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
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF42423F))),
          const SizedBox(height: 7),
          child,
        ],
      ),
    );
  }

  Widget statCard(String label, String value, IconData icon, Color accent) {
    return Container(
      width: 190,
      constraints: const BoxConstraints(minHeight: 104),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDFDFD8)),
        boxShadow: const [BoxShadow(color: Color(0x0A171717), blurRadius: 20, offset: Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: accent.withValues(alpha: .09), borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: accent, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF70706A))),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: Color(0xFF171717))),
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
        ? const Color(0xFF991B1B)
        : a['status'] == 2
            ? const Color(0xFF92400E)
            : const Color(0xFF166534);
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, c) {
            final compact = c.maxWidth < 760;
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(key(d), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(width: 8),
                    if (friday)
                      const _Badge(text: 'إجازة الجمعة', color: Color(0xFF70706A))
                    else
                      _Badge(text: status, color: statusColor),
                  ],
                ),
                const SizedBox(height: 6),
                if (!friday)
                  Text(
                    '${s == 'morning' ? '06:00 – 14:00' : '14:00 – 22:00'}  •  حضور ${durationText(a['worked']!)}  •  إضافي ${durationText(a['overtime']!)}  •  تأخير ${a['late']}د  •  مبكر ${a['early']}د',
                    style: const TextStyle(color: Color(0xFF70706A), height: 1.65, fontSize: 12),
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
            constraints: const BoxConstraints(maxWidth: 1380),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 42),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFDFDFD8)),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [BoxShadow(color: Color(0x0A171717), blurRadius: 24, offset: Offset(0, 8))],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(color: const Color(0xFFE9F5F2), borderRadius: BorderRadius.circular(30), border: Border.all(color: const Color(0xFFC5E3DE))),
                              child: const Text('FLUTTER WEB + SUPABASE', style: TextStyle(color: Color(0xFF0B5F59), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .5)),
                            ),
                            const SizedBox(height: 9),
                            const Text('نظام حساب دوام الموظفين', style: TextStyle(color: Color(0xFF171717), fontSize: 28, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 5),
                            const Text('إدارة الحضور والورديات المتناوبة والتأخير والانصراف المبكر والوقت الإضافي.', style: TextStyle(color: Color(0xFF70706A), fontSize: 13)),
                          ],
                        ),
                      ),
                      const Icon(Icons.schedule_rounded, color: Color(0xFF0F766E), size: 46),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('إعدادات الدوام', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 15),
                        Wrap(
                          spacing: 13,
                          runSpacing: 13,
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
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 9,
                          runSpacing: 9,
                          children: [
                            FilledButton.icon(onPressed: load, icon: const Icon(Icons.cloud_download_rounded), label: const Text('تحميل البيانات')),
                            FilledButton.icon(onPressed: save, icon: const Icon(Icons.save_rounded), label: const Text('حفظ التعديلات')),
                            if (message.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                child: Text(message, style: const TextStyle(color: Color(0xFF70706A), fontWeight: FontWeight.w600)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, c) {
                    final cardWidth = c.maxWidth < 600 ? c.maxWidth : c.maxWidth < 1000 ? (c.maxWidth - 12) / 2 : (c.maxWidth - 36) / 4;
                    final data = [
                      ('إجمالي الحضور', durationText(total), Icons.access_time_filled_rounded, const Color(0xFF0F766E)),
                      ('أيام العمل', (total / 480).toStringAsFixed(6), Icons.calendar_view_week_rounded, const Color(0xFF5F625F)),
                      ('الوقت الإضافي', durationText(totalOvertime), Icons.more_time_rounded, const Color(0xFF166534)),
                      ('التأخير', '$totalLate د', Icons.timer_off_rounded, const Color(0xFF92400E)),
                      ('الانصراف المبكر', '$totalEarly د', Icons.exit_to_app_rounded, const Color(0xFF92400E)),
                      ('الغياب', '$absent', Icons.person_off_rounded, const Color(0xFF991B1B)),
                      ('المعلق', '$pending', Icons.pending_actions_rounded, const Color(0xFF70706A)),
                    ];
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: data.map((x) => SizedBox(width: cardWidth, child: statCard(x.$1, x.$2, x.$3, x.$4))).toList(),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(child: Text('سجل أيام الدوام', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700))),
                    Text('${dates.length} يوم', style: const TextStyle(color: Color(0xFF70706A), fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 11),
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
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
