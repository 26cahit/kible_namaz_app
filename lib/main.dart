import 'dart:async';
import 'dart:math';
import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  runApp(const MyApp());
}

// ================= APP =================
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isDark = true;
  void toggleTheme() => setState(() => isDark = !isDark);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: isDark ? ThemeData.dark() : ThemeData.light(),
      home: SplashScreen(onToggleTheme: toggleTheme),
    );
  }
}

// ================= SPLASH =================
class SplashScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const SplashScreen({super.key, required this.onToggleTheme});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(seconds: 10), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => QiblaPage(onToggleTheme: widget.onToggleTheme),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0D1B2A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "🕌 KIBLE & NAMAZ UYGULAMASI",
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 15),

            Text("Hoşgeldiniz", style: TextStyle(fontSize: 15)),
            SizedBox(height: 15),

            Text("Developed by Cahit Acar", style: TextStyle(fontSize: 15)),
            SizedBox(height: 30),
            Text(
              "UYGULAMA AÇILIYOR...",
              style: TextStyle(
                fontSize: 18,
                color: Colors.greenAccent,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= MAIN PAGE =================
class QiblaPage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const QiblaPage({super.key, required this.onToggleTheme});

  @override
  State<QiblaPage> createState() => _QiblaPageState();
}

class _QiblaPageState extends State<QiblaPage> with WidgetsBindingObserver {
  bool isActive = true;
  double smoothedHeading = 0;
  double? qiblaDirection;
  String cityName = "";
  bool isCityLoading = true;
  late BannerAd _bannerAd;
  Map<String, String> prayerTimes = {};

  String _f(DateTime t) =>
      "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    Future.microtask(() => initAll());

    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3473720329862425/4134961402',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(),
    )..load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bannerAd.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      isActive = false;
    } else if (state == AppLifecycleState.resumed) {
      isActive = true;
    }
  }

  Future<void> initAll() async {
    try {
      await Geolocator.requestPermission();

      Position pos = await Geolocator.getCurrentPosition();

      qiblaDirection = calculateQiblaDirection(pos.latitude, pos.longitude);

      await getCityName(pos);

      calculatePrayerTimes(pos.latitude, pos.longitude);

      setState(() {});
    } catch (e) {
      print("HATA: $e");
    }
  }

  void calculatePrayerTimes(double lat, double lng) {
    final params = CalculationMethod.turkey.getParameters();
    final coordinates = Coordinates(lat, lng);
    final date = DateComponents.from(DateTime.now());

    final pt = PrayerTimes(coordinates, date, params);

    prayerTimes = {
      "İmsak": _f(pt.fajr),
      "Güneş": _f(pt.sunrise),
      "Öğle": _f(pt.dhuhr),
      "İkindi": _f(pt.asr),
      "Akşam": _f(pt.maghrib),
      "Yatsı": _f(pt.isha),
    };
  }

  Future<void> getCityName(Position pos) async {
    try {
      var p = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      cityName = p.first.administrativeArea ?? "";
    } catch (e) {
      cityName = "";
    }

    isCityLoading = false;
  }

  double calculateQiblaDirection(double lat, double lng) {
    const kaabaLat = 21.4225;
    const kaabaLng = 39.8262;

    double y = sin((kaabaLng - lng) * pi / 180);
    double x =
        cos(lat * pi / 180) * tan(kaabaLat * pi / 180) -
        sin(lat * pi / 180) * cos((kaabaLng - lng) * pi / 180);

    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          "🕌 KIBLE & NAMAZ UYGULAMASI",
          style: TextStyle(fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          SizedBox(height: 20),

          Text(
            isCityLoading
                ? "Konum alınıyor..."
                : cityName.isEmpty
                ? "Konum bulunamadı"
                : cityName,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(243, 59, 222, 4),
            ),
          ),

          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: prayerTimes.entries.map((e) {
              return Column(
                children: [
                  Text(
                    e.key,
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  SizedBox(height: 4),
                  Text(
                    e.value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
          Expanded(
            child: StreamBuilder<CompassEvent>(
              stream: FlutterCompass.events,
              builder: (context, snapshot) {
                if (!isActive) {
                  return const Center(child: Text("Arka planda"));
                }

                if (!snapshot.hasData ||
                    snapshot.data?.heading == null ||
                    qiblaDirection == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                double rawHeading = snapshot.data!.heading!;
                smoothedHeading =
                    smoothedHeading + (rawHeading - smoothedHeading) * 0.1;

                double qibla = qiblaDirection!;
                double diff = (smoothedHeading - qibla).abs();
                if (diff > 180) diff = 360 - diff;

                bool isQibla = diff < 10;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          if (isQibla)
                            BoxShadow(
                              color: Colors.greenAccent.withOpacity(0.5),
                              blurRadius: 1,
                              spreadRadius: 1,
                            ),
                        ],
                      ),
                      child: CustomPaint(
                        size: const Size(300, 300),
                        painter: CompassPainter(
                          heading: smoothedHeading,
                          qiblaDirection: qibla,
                          isQibla: isQibla,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isQibla ? "✔ KIBLE BULUNDU" : "KIBLE İÇİN TELEFONU ÇEVİR",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: isQibla ? Colors.greenAccent : Colors.white70,
                        shadows: isQibla
                            ? [Shadow(color: Colors.greenAccent, blurRadius: 5)]
                            : [],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ================= COMPASS =================
class CompassPainter extends CustomPainter {
  final double heading;
  final double qiblaDirection;
  final bool isQibla;

  CompassPainter({
    required this.heading,
    required this.qiblaDirection,
    required this.isQibla,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white24
        ..style = PaintingStyle.stroke,
    );
    void drawTextDual(String short, String long, Offset pos, Color color) {
      final tp = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: "$short\n",
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextSpan(
              text: long,
              style: TextStyle(color: color.withOpacity(0.7), fontSize: 20),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );

      tp.layout();
      tp.paint(canvas, pos);
    }

    canvas.drawCircle(center, 5, Paint()..color = Colors.white);
    // 🔥 YÖNLER (DÖNER)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-heading * pi / 180);
    canvas.translate(-center.dx, -center.dy);

    drawTextDual(
      "N",
      "Kuzey",
      Offset(center.dx - 10, center.dy - radius + 5),
      Colors.red,
    );

    drawTextDual(
      "S",
      "Güney",
      Offset(center.dx - 10, center.dy + radius - 35),
      Colors.blue,
    );

    drawTextDual(
      "E",
      "Doğu",
      Offset(center.dx + radius - 25, center.dy - 15),
      Colors.green,
    );

    drawTextDual(
      "W",
      "Batı",
      Offset(center.dx - radius + 5, center.dy - 15),
      Colors.orange,
    );

    canvas.restore();

    final paint = Paint()..color = isQibla ? Colors.green : Colors.red;

    final path = Path();
    path.moveTo(center.dx, center.dy - radius + 20);
    path.lineTo(center.dx - 12, center.dy);
    path.lineTo(center.dx + 12, center.dy);
    path.close();

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate((qiblaDirection - heading) * pi / 180);
    canvas.translate(-center.dx, -center.dy);

    canvas.drawPath(path, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
