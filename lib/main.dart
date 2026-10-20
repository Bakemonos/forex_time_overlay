import 'dart:async';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:window_manager/window_manager.dart';

//? SESSIONS SETTINGS
class Session {
  final String name, zone;
  final int open, close;
  const Session({required this.name, required this.zone, required this.open, required this.close});

  // bool isOpen(DateTime nowUtc) {
  //   final t = tz.TZDateTime.from(nowUtc, tz.getLocation(zone));
  //   if (t.weekday == DateTime.saturday || t.weekday == DateTime.sunday) {
  //     return false;
  //   }
  //   return t.hour >= open && t.hour < close;
  // }

  bool isOpen(DateTime nowUtc) {
    final t = tz.TZDateTime.from(nowUtc, tz.getLocation(zone));
    if (t.weekday == DateTime.saturday || t.weekday == DateTime.sunday) {
      return false;
    }
    final h = t.hour;
    if (open < close) {
      return h >= open && h < close; 
    }
    return h >= open || h < close;
  }

  String _hourLabel(int h) {
    final hour24 = h % 24;
    final period = hour24 >= 12 ? 'pm' : 'am';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$hour12$period';
  }

  String openingRange() {
    return '${_hourLabel(open)} - ${_hourLabel(close)}';
  }

  String localTime(DateTime nowUtc) {
    final t = tz.TZDateTime.from(nowUtc, tz.getLocation(zone));
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}

const sessions = [
  Session(
    name: 'Sydney',
    zone: 'Australia/Sydney',
    open: 9,
    close: 18,
  ),
  Session(
    name: 'Tokyo',
    zone: 'Asia/Tokyo',
    open: 9,
    close: 18,
  ),
  Session(
    name: 'London',
    zone: 'Europe/London',
    open: 8,
    close: 17,
  ),
  Session(
    name: 'New York',
    zone: 'America/New_York',
    open: 8,
    close: 17,
  ),
];

//? SETTINGS
bool kShowBackground = false;

const kAsiaZone = 'Asia/Manila';
const Size kStartSize = Size(700, 160);

const _shadow = [Shadow(color: Colors.black, blurRadius: 4)];

//? MAIN
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();

  if (Platform.isWindows) {
    await Window.initialize();
    await Window.setEffect(
      effect: WindowEffect.transparent,
      color: Colors.transparent,
    );
  }

  await windowManager.ensureInitialized();

  const options = WindowOptions(
    size: kStartSize,
    alwaysOnTop: true,
    titleBarStyle: TitleBarStyle.hidden,
    backgroundColor: Colors.transparent,
  );

  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setAsFrameless();
    await windowManager.setHasShadow(false);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setMaximizable(false);
    await windowManager.setMinimumSize(const Size(500, 100));
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
    ),
    home: const Scaffold(
      backgroundColor: Colors.transparent,
      body: SessionOverlay(),
    ),
  ));
}

//? OVERLAY
class SessionOverlay extends StatefulWidget {
  const SessionOverlay({super.key});
  @override
  State<SessionOverlay> createState() => _SessionOverlayState();
}

class _SessionOverlayState extends State<SessionOverlay> {
  late Timer _timer;
  DateTime _now = DateTime.now().toUtc();

  Size _startSize = kStartSize;
  Offset _startPos = Offset.zero;
  bool _resizing = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1),
      (_) => setState(() => _now = DateTime.now().toUtc()));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _onDown(PointerDownEvent e) async {
    if (e.buttons == kSecondaryMouseButton) {
      _startPos = e.position;
      _resizing = true;
      _startSize = await windowManager.getSize();
    }
  }

  void _onMove(PointerMoveEvent e) {
    if (!_resizing) return;
    final dx = e.position.dx - _startPos.dx;
    final newW = (_startSize.width + dx).clamp(200.0, 1200.0);
    final ratio = kStartSize.height / kStartSize.width;
    windowManager.setSize(Size(newW, newW * ratio));
  }

  void _onUp(PointerUpEvent e) => _resizing = false;

  String formatTime(String time, bool isMilitaryTime) {
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    final dateTime = DateTime(2000, 1, 1, hour, minute);

    if (isMilitaryTime) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:'
          '${dateTime.minute.toString().padLeft(2, '0')}';
    }

    final formattedHour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';

    return '$formattedHour:'
        '${dateTime.minute.toString().padLeft(2, '0')} $period';
  }

  String get currentTime  {
    final t = tz.TZDateTime.from(_now, tz.getLocation(kAsiaZone));
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Widget _sessionItem(Session s) {
    final open = s.isOpen(_now);
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatTime(s.localTime(_now), false),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w600,
              shadows: _shadow,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: open ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                s.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  shadows: _shadow,
                ),
              ),
            ],
          ),
          Text(
            s.openingRange(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              shadows: _shadow,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      child: DragToMoveArea(
        child: SizedBox.expand(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kShowBackground
                  ? Colors.black87
                  : Colors.black.withAlpha(3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 800,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          spacing: 8,
                          children: [
                            Text(
                              'Forex Sessions | Current Time: ${formatTime(currentTime, false)}',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                shadows: _shadow,
                              ),
                            ),
                            InkWell(
                              onTap: (){
                                kShowBackground = !kShowBackground;
                              },
                              child: Icon(
                                kShowBackground ? Icons.remove_red_eye : Icons.visibility_off,
                                color: Colors.white,
                                size: 18,
                              )
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () => windowManager.close(),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white70,
                            shadows: _shadow,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: sessions.map(_sessionItem).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}