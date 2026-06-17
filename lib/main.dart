import 'dart:async';
import 'dart:math';
import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:home_widget/home_widget.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'dart:ui';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'data/short_quotes.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
String? startupPayload;
// RANDOM SÖZ ÇEKEN FONKSİYON - YENİ EKLENDİ
Future<Map<String, dynamic>> getRandomSoz() async {
  final String response = await rootBundle.loadString('assets/words.json');
  final List data = await json.decode(response);
  final random = Random().nextInt(data.length);
  return data[random];
}

Future<Map<String, dynamic>> getGununSozu() async {
  final String response = await rootBundle.loadString('assets/words.json');

  final List data = json.decode(response);

  final gunKodu = DateTime.now().difference(DateTime(2025, 1, 1)).inDays;

  final index = gunKodu % data.length;

  return data[index];
}

Future<Map<String, dynamic>?> getBugununOzelGunu() async {
  final response = await rootBundle.loadString('assets/ozel_gunler.json');

  final List data = json.decode(response);

  final now = DateTime.now();

  for (final item in data) {
    if (item['ay'] == now.month && item['gun'] == now.day) {
      return item;
    }
  }

  return null;
}

String? getBugununDiniGunu() {
  final h = HijriCalendar.now();

  if (h.hMonth == 7 && h.hDay == 27) {
    return "🕌 Miraç Kandili";
  }

  if (h.hMonth == 8 && h.hDay == 15) {
    return "🕌 Berat Kandili";
  }

  if (h.hMonth == 9 && h.hDay == 1) {
    return "🌙 Ramazan Başlangıcı";
  }

  if (h.hMonth == 9 && h.hDay == 27) {
    return "⭐ Kadir Gecesi";
  }

  if (h.hMonth == 10 && h.hDay == 1) {
    return "🎉 Ramazan Bayramı";
  }

  if (h.hMonth == 12 && h.hDay == 10) {
    return "🐑 Kurban Bayramı";
  }

  if (h.hMonth == 3 && h.hDay == 12) {
    return "🌹 Mevlid Kandili";
  }

  return null;
}

@pragma('vm:entry-point')
Future<void> updateWidgetAlarm() async {
  debugPrint("ALARM CALISTI");
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

  final prefs = await SharedPreferences.getInstance();

  final cityName = prefs.getString('last_city') ?? 'Eskişehir';

  String? savedLat = prefs.getString('last_lat');
  String? savedLng = prefs.getString('last_lng');

  if (savedLat == null || savedLng == null) {
    return;
  }

  final lat = double.parse(savedLat);
  final lng = double.parse(savedLng);

  final params = CalculationMethod.turkey.getParameters();

  final coordinates = Coordinates(lat, lng);

  final date = DateComponents.from(DateTime.now());

  final pt = PrayerTimes(coordinates, date, params);

  final vakitler = {
    "İmsak": pt.fajr,
    "Öğle": pt.dhuhr,
    "İkindi": pt.asr,
    "Akşam": pt.maghrib,
    "Yatsı": pt.isha,
  };

  String sonrakiVakit = "İmsak";

  final yarin = DateTime.now().add(const Duration(days: 1));

  final yarinDate = DateComponents(yarin.year, yarin.month, yarin.day);

  final yarinPt = PrayerTimes(coordinates, yarinDate, params);

  DateTime sonrakiSaat = yarinPt.fajr;

  for (final item in vakitler.entries) {
    if (item.value.isAfter(DateTime.now())) {
      sonrakiVakit = item.key;
      sonrakiSaat = item.value;
      break;
    }
  }

  await HomeWidget.saveWidgetData('widget_sehir', cityName);

  await HomeWidget.saveWidgetData('widget_vakit', sonrakiVakit);
  debugPrint("WIDGET => $sonrakiVakit");
  await HomeWidget.saveWidgetData(
    'widget_saat',
    "${sonrakiSaat.hour.toString().padLeft(2, '0')}:${sonrakiSaat.minute.toString().padLeft(2, '0')}",
  );

  await HomeWidget.updateWidget(androidName: 'NamazWidgetProvider');
  final randomQuote = shortQuotes[Random().nextInt(shortQuotes.length)];
  await FlutterForegroundTask.updateService(
    notificationTitle: '🕌 Sonraki Vakit: $sonrakiVakit',
    notificationText:
        '${sonrakiSaat.hour.toString().padLeft(2, '0')}:${sonrakiSaat.minute.toString().padLeft(2, '0')} • $cityName\n$randomQuote',
  );
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    tz.initializeTimeZones();

    final location = tz.getLocation('Europe/Istanbul');
    tz.setLocalLocation(location);

    final FlutterLocalNotificationsPlugin notifications =
        FlutterLocalNotificationsPlugin();

    //await notifications.cancelAll();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await notifications.initialize(
      const InitializationSettings(android: android),
    );

    const AndroidNotificationChannel namazChannel = AndroidNotificationChannel(
      'namaz_channel_v2',
      'Namaz Bildirimleri',
      description: 'Namaz vakti bildirimleri',
      importance: Importance.max,
      sound: RawResourceAndroidNotificationSound('ses'),
      playSound: true,
    );

    await notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(namazChannel);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wm_test', DateTime.now().toString());
    final cityName = prefs.getString('last_city') ?? 'Eskişehir';
    String? savedLat = prefs.getString('last_lat');
    String? savedLng = prefs.getString('last_lng');
    if (savedLat == null || savedLng == null) return Future.value(true);

    double lat = double.parse(savedLat);
    double lng = double.parse(savedLng);

    final params = CalculationMethod.turkey.getParameters();
    final coordinates = Coordinates(lat, lng);
    final date = DateComponents.from(DateTime.now());
    final pt = PrayerTimes(coordinates, date, params);

    final now = tz.TZDateTime.now(location);
    final times = {
      "İmsak": pt.fajr,
      "Öğle": pt.dhuhr,
      "İkindi": pt.asr,
      "Akşam": pt.maghrib,
      "Yatsı": pt.isha,
    };
    String sonrakiVakit = "İmsak";

    final yarin = DateTime.now().add(const Duration(days: 1));

    final yarinDate = DateComponents(yarin.year, yarin.month, yarin.day);

    final yarinPt = PrayerTimes(coordinates, yarinDate, params);

    DateTime sonrakiSaat = yarinPt.fajr;

    for (final item in times.entries) {
      if (item.value.isAfter(DateTime.now())) {
        sonrakiVakit = item.key;
        sonrakiSaat = item.value;
        break;
      }
    }

    int id = 0;
    for (final entry in times.entries) {
      final name = entry.key;
      var time = tz.TZDateTime.from(entry.value, location);

      if (time.isBefore(now)) {
        time = time.add(const Duration(days: 1));
      }

      final before = time.subtract(const Duration(minutes: 10));
    }

    await HomeWidget.saveWidgetData<String>('widget_sehir', cityName);

    await HomeWidget.saveWidgetData<String>('widget_vakit', sonrakiVakit);

    await HomeWidget.saveWidgetData<String>(
      'widget_saat',
      "${sonrakiSaat.hour.toString().padLeft(2, '0')}:${sonrakiSaat.minute.toString().padLeft(2, '0')}",
    );

    await HomeWidget.updateWidget(androidName: 'NamazWidgetProvider');
    final randomQuote = shortQuotes[Random().nextInt(shortQuotes.length)];
    await FlutterForegroundTask.updateService(
      notificationTitle: '🕌 Sonraki Vakit: $sonrakiVakit',
      notificationText:
          '${sonrakiSaat.hour.toString().padLeft(2, '0')}:${sonrakiSaat.minute.toString().padLeft(2, '0')} • $cityName\n$randomQuote',
    );
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AndroidAlarmManager.initialize();
  await AndroidAlarmManager.periodic(
    const Duration(minutes: 30),
    999,
    updateWidgetAlarm,
    wakeup: true,
  );
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

  final FlutterLocalNotificationsPlugin notifications =
      FlutterLocalNotificationsPlugin();
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');

  // DEĞİŞTİ - BİLDİRİME TIKLANINCA DİYALOG AÇAR
  await notifications.initialize(
    const InitializationSettings(android: android),
    onDidReceiveNotificationResponse: (details) async {
      if (details.payload != null) {
        final String response = await rootBundle.loadString(
          'assets/words.json',
        );
        final List data = await json.decode(response);
        final soz = data.firstWhere(
          (e) => e['id'].toString() == details.payload,
        );

        showDialog(
          context: navigatorKey.currentContext!,
          builder: (_) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Dialog(
                backgroundColor: Colors.transparent,

                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(22),

                  decoration: BoxDecoration(
                    color: const Color(0xFF102027),

                    borderRadius: BorderRadius.circular(24),

                    border: Border.all(
                      color: Colors.greenAccent.withOpacity(0.3),
                      width: 1.2,
                    ),
                  ),

                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),

                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.greenAccent.withOpacity(0.12),
                        ),

                        child: const Icon(
                          Icons.auto_awesome,
                          color: Colors.greenAccent,
                          size: 34,
                        ),
                      ),

                      const SizedBox(height: 18),

                      const Text(
                        "📿 Günün Sözü",
                        textAlign: TextAlign.center,

                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.greenAccent,
                        ),
                      ),

                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          soz['tur'] == 'hadis'
                              ? "✨ HADİS-İ ŞERİF ✨"
                              : soz['tur'] == 'ayet'
                              ? "📖 AYET-İ KERİME 📖"
                              : "🌿 HİKMETLİ SÖZ 🌿",
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                      Text(
                        soz['tam'],
                        textAlign: TextAlign.center,

                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.6,
                          color: Colors.white70,
                        ),
                      ),

                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.share),

                          label: const Text(
                            "Paylaş",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),

                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1F1B2E),
                            foregroundColor: Colors.greenAccent,

                            side: const BorderSide(
                              color: Colors.greenAccent,
                              width: 1.5,
                            ),

                            minimumSize: const Size(double.infinity, 58),

                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),

                          onPressed: () {
                            Share.share(
                              "${soz['tam']}\n\n🕌 Kıble Pusulası ve Namaz Vakitleri Uygulaması",
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,

                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.favorite),

                          label: const Text(
                            "KAPAT",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),

                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent,
                            foregroundColor: Colors.black,
                          ),

                          onPressed: () {
                            Navigator.pop(navigatorKey.currentContext!);
                          },
                        ),
                      ),
                      const SizedBox(height: 15),

                      const Text(
                        "🕌 Kıble Pusulası ve Namaz Vakitleri",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }
    },
  );
  final NotificationAppLaunchDetails? launchDetails = await notifications
      .getNotificationAppLaunchDetails();

  if (launchDetails?.didNotificationLaunchApp ?? false) {
    startupPayload = launchDetails!.notificationResponse?.payload;
  }
  await MobileAds.instance.initialize();
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'namaz_lockscreen',
      channelName: 'Kilit Ekranı Namaz Bilgisi',
      channelDescription: 'Sonraki namaz vakti',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
    ),
    iosNotificationOptions: const IOSNotificationOptions(),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(1800000),
      autoRunOnBoot: true,
      autoRunOnMyPackageReplaced: true,
    ),
  );
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  final prefs = await SharedPreferences.getInstance();

  final sehir = prefs.getString('widget_sehir') ?? 'Eskişehir';

  final vakit = prefs.getString('widget_vakit') ?? 'İmsak';

  final saat = prefs.getString('widget_saat') ?? '--:--';
  await FlutterForegroundTask.startService(
    notificationTitle: '🕌 Sonraki Vakit: $vakit',
    notificationText: '$saat • $sehir',
  );
  runApp(const MyApp());
}

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
      navigatorKey: navigatorKey, // YENİ EKLENDİ
      debugShowCheckedModeBanner: false,
      theme: isDark ? ThemeData.dark() : ThemeData.light(),
      home: SplashScreen(onToggleTheme: toggleTheme),
    );
  }
}

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

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;

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
              "KIBLE PUSULASI",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.greenAccent,
              ),
            ),
            SizedBox(height: 6),
            Text(
              "NAMAZ VAKİTLERİ UYGULAMASINA",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
            SizedBox(height: 20),
            Text(
              "Hoş geldiniz",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, color: Colors.white60),
            ),
            SizedBox(height: 30),
            Text(
              "Developed by Cahit Acar",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.white38),
            ),
          ],
        ),
      ),
    );
  }
}

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
  String calculationMethod = "turkey";
  CalculationParameters getCalculationParams() {
    switch (calculationMethod) {
      case "turkey":
        return CalculationMethod.turkey.getParameters();

      case "muslim_world_league":
        return CalculationMethod.muslim_world_league.getParameters();

      case "umm_al_qura":
        return CalculationMethod.umm_al_qura.getParameters();

      case "north_america":
        return CalculationMethod.north_america.getParameters();

      default:
        return CalculationMethod.turkey.getParameters();
    }
  }

  bool isCityLoading = true;
  BannerAd? _bannerAd;
  Map<String, String> prayerTimes = {};
  bool vibrationEnabled = true;

  bool batteryButtonHidden = false;
  bool batteryPromptShown = false;
  bool locationDialogShown = false;
  bool _notificationScheduling = false;
  Map<String, dynamic>? gununSozu;
  ScrollController _scrollController = ScrollController();
  bool _showDownArrow = true;
  final AudioPlayer _audioPlayer = AudioPlayer(); // EKLE
  bool kibleSesiCalindi = false;
  String getTurkishHijriMonth(String month) {
    const months = {
      'Muharram': 'Muharrem',
      'Safar': 'Safer',
      'Rabi Al-Awwal': 'Rebiülevvel',
      'Rabi Al-Thani': 'Rebiülahir',
      'Jumada Al-Awwal': 'Cemaziyelevvel',
      'Jumada Al-Thani': 'Cemaziyelahir',
      'Rajab': 'Recep',
      'Shaaban': 'Şaban',
      'Ramadan': 'Ramazan',
      'Shawwal': 'Şevval',
      'Dhu Al-Qadah': 'Zilkade',
      'Dhu Al-Hijjah': 'Zilhicce',
    };

    return months[month] ?? month;
  }

  Future<void> openMail() async {
    final Uri emailUri = Uri.parse('mailto:cahitacar.dev@gmail.com');
    await launchUrl(emailUri, mode: LaunchMode.externalApplication);
  }

  Future<void> openInstagram() async {
    final Uri instaUri = Uri.parse(
      'https://instagram.com/acardijitalpazarlama',
    );
    if (await canLaunchUrl(instaUri)) {
      await launchUrl(instaUri, mode: LaunchMode.externalApplication);
    }
  }

  final FlutterLocalNotificationsPlugin notifications =
      FlutterLocalNotificationsPlugin();

  String _f(DateTime t) =>
      "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initAll();
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3473720329862425/4134961402',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(),
    )..load();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 50) {
        if (_showDownArrow) setState(() => _showDownArrow = false);
      } else {
        if (!_showDownArrow) setState(() => _showDownArrow = true);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _bannerAd?.dispose();
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

  void showUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/icon.png', width: 100, height: 100),

              const SizedBox(height: 15),

              const Text(
                "Uygulamanızı Güncelleyin",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 15),

              const Text(
                "Yeni sürüm yayınlandı.\n\n• Ana ekran paneli eklendi\n• Günün Sözü özelliği geliştirildi\n• Bildirim sistemi iyileştirildi\n• Performans artırıldı\n\nDevam etmek için uygulamayı güncelleyin.",
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 25),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      await InAppUpdate.performImmediateUpdate();
                    } catch (e) {
                      debugPrint(e.toString());
                    }
                  },

                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 55),
                  ),

                  child: const Text(
                    "🚀 Hemen Güncelle",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> checkForUpdate() async {
    try {
      final info = await InAppUpdate.checkForUpdate();

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        showUpdateDialog();
      }
    } catch (e) {
      debugPrint("Güncelleme kontrol hatası: $e");
    }
  }

  Future<void> initAll() async {
    gununSozu = await getGununSozu();
    if (startupPayload != null) {
      Future.delayed(const Duration(seconds: 2), () async {
        final String response = await rootBundle.loadString(
          'assets/words.json',
        );

        final List data = json.decode(response);

        final soz = data.firstWhere(
          (e) => e['id'].toString() == startupPayload,
        );

        if (!mounted) return;

        showDialog(
          context: context,
          builder: (_) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF102027),
                  borderRadius: BorderRadius.circular(28),

                  border: Border.all(
                    color: Colors.greenAccent.withOpacity(0.4),
                    width: 1.5,
                  ),

                  boxShadow: [
                    BoxShadow(
                      color: Colors.greenAccent.withOpacity(0.25),
                      blurRadius: 25,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.8, end: 1.0),
                      duration: const Duration(milliseconds: 600),
                      builder: (context, value, child) {
                        return Transform.scale(scale: value, child: child);
                      },
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.greenAccent,
                        size: 55,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "📖 Günün Sözü",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.greenAccent,
                      ),
                    ),
                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        soz['tur'] == 'hadis'
                            ? "✨ HADİS-İ ŞERİF ✨"
                            : soz['tur'] == 'ayet'
                            ? "📖 AYET-İ KERİME 📖"
                            : "🌿 HİKMETLİ SÖZ 🌿",
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(soz['tam'], textAlign: TextAlign.center),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.share),
                        label: const Text(
                          "Paylaş",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1F1B2E),
                          foregroundColor: Colors.greenAccent,

                          side: const BorderSide(
                            color: Colors.greenAccent,
                            width: 1.5,
                          ),

                          minimumSize: const Size(double.infinity, 58),

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () {
                          Share.share(
                            "${soz['tam']}\n\n🕌 Kıble Pusulası ve Namaz Vakitleri Uygulaması",
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.favorite),
                        label: const Text("Kapat"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent,
                          foregroundColor: Colors.black,
                        ),

                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                    ),
                    const SizedBox(height: 15),

                    const Text(
                      "🕌 Kıble Pusulası ve Namaz Vakitleri",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          },
        );

        startupPayload = null;
      });
    }
    await checkForUpdate();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? lastExactAlarmAsk = prefs.getInt('last_exact_alarm_ask');
    debugPrint("WM TEST = ${prefs.getString('wm_test')}");
    bool tekrarSor = true;

    if (lastExactAlarmAsk != null) {
      final fark = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(lastExactAlarmAsk))
          .inHours;

      if (fark < 24) {
        tekrarSor = false;
      }
    }
    batteryPromptShown = prefs.getBool('battery_prompt_shown') ?? false;
    if (batteryPromptShown) {
      batteryButtonHidden = true;
    }
    locationDialogShown = prefs.getBool('location_dialog_shown') ?? false;
    String? savedLat = prefs.getString('last_lat');
    String? savedLng = prefs.getString('last_lng');
    if (savedLat != null && savedLng != null) {
      double lat = double.parse(savedLat);
      double lng = double.parse(savedLng);
      calculatePrayerTimes(lat, lng);
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {},
    );

    final androidPlugin = notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    final bool? izinVar = await androidPlugin?.canScheduleExactNotifications();

    if (izinVar == false && mounted && tekrarSor) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            "⏰ Namaz Bildirimleri",
            textAlign: TextAlign.center,
          ),
          content: const Text(
            "Namaz vakitlerinin tam saatinde çalışması için alarm izni gerekiyor.",
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await prefs.setInt(
                  'last_exact_alarm_ask',
                  DateTime.now().millisecondsSinceEpoch,
                );

                Navigator.pop(context);
              },
              child: const Text("Sonra"),
            ),
            ElevatedButton(
              onPressed: () async {
                await prefs.setInt(
                  'last_exact_alarm_ask',
                  DateTime.now().millisecondsSinceEpoch,
                );

                Navigator.pop(context);

                await androidPlugin?.requestExactAlarmsPermission();
              },
              child: const Text("İzin Ver"),
            ),
          ],
        ),
      );
    }
    const AndroidNotificationChannel namazChannel = AndroidNotificationChannel(
      'namaz_channel_v2',
      'Namaz Bildirimleri',
      description: 'Namaz vakti bildirimleri',
      importance: Importance.max,
      sound: RawResourceAndroidNotificationSound('ses'),
      playSound: true,
    );

    //YORUM SATIRINI KALDIR -
    /*await notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.deleteNotificationChannel('namaz_channel_v2');
*/
    await notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(namazChannel);

    const AndroidNotificationChannel testChannel = AndroidNotificationChannel(
      'test_channel',
      'Test Bildirimleri',
      description: 'Test',
      importance: Importance.max,
    );

    await notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(testChannel);

    await notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    try {
      if (!locationDialogShown) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Konum İzni"),
            content: const Text(
              "Kıble yönü ve namaz saatlerini doğru hesaplamak için konumunuza ihtiyaç duyuyoruz.",
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  SharedPreferences prefs =
                      await SharedPreferences.getInstance();
                  await prefs.setBool('location_dialog_shown', true);
                  Navigator.pop(context);
                },
                child: const Text(
                  "Tamam",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
        locationDialogShown = true;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        return;
      }
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Konum izni verilmedi")));
        return;
      }

      Geolocator.getCurrentPosition().then((pos) async {
        qiblaDirection = calculateQiblaDirection(pos.latitude, pos.longitude);

        if (mounted) setState(() {});

        await getCityName(pos);

        await calculatePrayerTimes(pos.latitude, pos.longitude);

        if (!_notificationScheduling) {
          _notificationScheduling = true;

          await schedulePrayerNotifications(pos.latitude, pos.longitude);
        }
      });

      setState(() {});
    } catch (e) {
      print("HATA: $e");
    }
  }

  Future<void> calculatePrayerTimes(double lat, double lng) async {
    final params = getCalculationParams();
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
    final now = DateTime.now();

    String sonrakiVakit = "İmsak";

    final yarin = DateTime.now().add(const Duration(days: 1));

    final yarinDate = DateComponents(yarin.year, yarin.month, yarin.day);

    final yarinPt = PrayerTimes(coordinates, yarinDate, params);

    DateTime sonrakiSaat = yarinPt.fajr;

    final vakitler = {
      "İmsak": pt.fajr,
      "Öğle": pt.dhuhr,
      "İkindi": pt.asr,
      "Akşam": pt.maghrib,
      "Yatsı": pt.isha,
    };

    for (final item in vakitler.entries) {
      if (item.value.isAfter(now)) {
        sonrakiVakit = item.key;
        sonrakiSaat = item.value;
        break;
      }
    }

    await HomeWidget.saveWidgetData<String>('widget_sehir', cityName);

    await HomeWidget.saveWidgetData<String>('widget_vakit', sonrakiVakit);

    await HomeWidget.saveWidgetData<String>('widget_saat', _f(sonrakiSaat));

    await HomeWidget.updateWidget(androidName: 'NamazWidgetProvider');
    final randomQuote = shortQuotes[Random().nextInt(shortQuotes.length)];
    await FlutterForegroundTask.updateService(
      notificationTitle: '🕌 Sonraki Vakit: $sonrakiVakit',
      notificationText:
          '${sonrakiSaat.hour.toString().padLeft(2, '0')}:${sonrakiSaat.minute.toString().padLeft(2, '0')} • $cityName\n$randomQuote',
    );
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_lat', lat.toString());
    await prefs.setString('last_lng', lng.toString());
    if (mounted) setState(() {});
  }

  Future<void> schedulePrayerNotifications(double lat, double lng) async {
    final prefs = await SharedPreferences.getInstance();
    final cityName = prefs.getString('last_city') ?? 'Eskişehir';
    String? lastScheduleDate = prefs.getString('last_schedule_date');

    String today =
        "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}";

    final pending = await notifications.pendingNotificationRequests();

    if (lastScheduleDate == today && pending.length > 50) {
      return;
    }
    await notifications.cancelAll();

    final params = getCalculationParams();

    final coordinates = Coordinates(lat, lng);

    int id = 2000;
    final ozelGun = await getBugununOzelGunu();

    if (ozelGun != null) {
      final bildirimSaati = tz.TZDateTime(
        tz.local,
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        9,
        0,
      );

      if (bildirimSaati.isAfter(tz.TZDateTime.now(tz.local))) {
        await notifications.zonedSchedule(
          99999,
          ozelGun['baslik'],
          ozelGun['mesaj'],
          bildirimSaati,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'namaz_channel_v2',
              'Namaz Bildirimleri',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }

    for (int gun = 0; gun < 7; gun++) {
      final hedefTarih = DateTime.now().add(Duration(days: gun));

      final date = DateComponents(
        hedefTarih.year,
        hedefTarih.month,
        hedefTarih.day,
      );

      final pt = PrayerTimes(coordinates, date, params);

      final vakitler = {
        "İmsak": pt.fajr,
        "Öğle": pt.dhuhr,
        "İkindi": pt.asr,
        "Akşam": pt.maghrib,
        "Yatsı": pt.isha,
      };

      for (final item in vakitler.entries) {
        var vakit = tz.TZDateTime.from(item.value, tz.local);

        final now = tz.TZDateTime.now(tz.local);

        if (vakit.isBefore(now)) {
          vakit = vakit.add(const Duration(days: 1));
        }
        final once = vakit.subtract(const Duration(minutes: 10));

        if (vakit.isAfter(tz.TZDateTime.now(tz.local))) {
          await notifications.zonedSchedule(
            id++,
            "🕌 ${item.key} Namazı Vakti",
            "${item.key} vakti girdi.",
            vakit,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'namaz_channel_v2',
                'Namaz Bildirimleri',
                importance: Importance.max,
                priority: Priority.high,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        }
      }
    }
    for (int gun = 0; gun < 7; gun++) {
      final hedefTarih = DateTime.now().add(Duration(days: gun));

      final sozSaatleri = [9, 15, 21];

      for (final saat in sozSaatleri) {
        final soz = await getGununSozu();

        final bildirimVakti = tz.TZDateTime(
          tz.local,
          hedefTarih.year,
          hedefTarih.month,
          hedefTarih.day,
          saat,
          0,
        );

        if (bildirimVakti.isAfter(tz.TZDateTime.now(tz.local))) {
          await notifications.zonedSchedule(
            id++,
            "📖 Günün Sözü",
            "Bugünün sözünü okumak için dokunun",
            bildirimVakti,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'namaz_channel_v2',
                'Namaz Bildirimleri',
                importance: Importance.max,
                priority: Priority.high,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: soz['id'].toString(),
          );
        }
      }
    }
    await prefs.setString('last_schedule_date', today);
  }

  Future<void> getCityName(Position pos) async {
    try {
      var p = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      cityName = p.first.administrativeArea ?? "";
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_city', cityName);
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

  Future<void> openBatterySettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('battery_prompt_shown', true);
    setState(() {
      batteryButtonHidden = true;
    });
    final intent = AndroidIntent(
      action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
    );
    await intent.launch();
  }

  @override
  Widget build(BuildContext context) {
    final hijri = HijriCalendar.now();
    final diniGun = getBugununDiniGunu();
    final mainColor = Color.fromARGB(243, 59, 222, 4);
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Center(
          child: Text(
            "🕌 KIBLE VE NAMAZ SAATLERİ UYGULAMASI",
            style: TextStyle(fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.greenAccent),
            onSelected: (value) async {
              if (value == "Titresim") {
                setState(() {
                  vibrationEnabled = !vibrationEnabled;
                });
              }
              if (value == "bugun") {
                final diniGun = getBugununDiniGunu();

                final ozelGun = await getBugununOzelGunu();

                showDialog(
                  context: context,
                  builder: (_) {
                    return AlertDialog(
                      title: const Text(
                        "📅 Bugün Ne Günü?",
                        textAlign: TextAlign.center,
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "🕌 Dini Gün",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.greenAccent,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            diniGun ?? "Bugün özel dini gün bulunmuyor",
                            style: const TextStyle(fontSize: 16),
                          ),

                          const SizedBox(height: 20),

                          const Text(
                            "🇹🇷 Resmi Gün",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.redAccent,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            ozelGun?['baslik'] ??
                                "Bugün resmi özel gün bulunmuyor",
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                      actions: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle),
                            label: const Text(
                              "Tamam",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.greenAccent,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      ],
                    );
                  },
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: "Titresim",

                child: Row(
                  children: [
                    Icon(
                      vibrationEnabled ? Icons.vibration : Icons.phone_android,
                    ),
                    const SizedBox(width: 10),
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: vibrationEnabled
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          vibrationEnabled
                              ? "Titreşim Açık"
                              : "Titreşim Kapalı",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: vibrationEnabled
                                ? Colors.greenAccent
                                : Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: "bugun",
                child: Row(
                  children: const [
                    Icon(Icons.event),
                    SizedBox(width: 10),
                    Text("📅 Bugün Ne Günü?"),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            children: [
              const SizedBox(height: 20),
              Text(
                isCityLoading
                    ? "KONUM BEKLENİYOR\n\nKonumunuzu ve internetinizi kontrol edin."
                    : cityName.isEmpty
                    ? "İnternet veya konum hatası. Yenilemeyi deneyin"
                    : cityName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: MediaQuery.of(context).size.width * 0.045,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(243, 59, 222, 4),
                ),
              ),
              const SizedBox(height: 10),
              if (!batteryButtonHidden)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ElevatedButton.icon(
                    onPressed: openBatterySettings,
                    icon: const Icon(Icons.battery_saver),
                    label: FittedBox(
                      child: Text(
                        "Bildirimler Gelmiyorsa Batarya(PİL) Ayarlarını Kontrol Edin",
                        textAlign: TextAlign.center,
                        softWrap: true,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1F1B2E),
                      foregroundColor: Colors.greenAccent,

                      side: const BorderSide(
                        color: Colors.greenAccent,
                        width: 1.5,
                      ),

                      minimumSize: const Size(double.infinity, 58),

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              if (cityName.isEmpty) ...[
                ElevatedButton.icon(
                  onPressed: initAll,
                  icon: const Icon(Icons.refresh, size: 20),
                  label: const Text(
                    "Yenile",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C853),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 6,
                    shadowColor: Colors.greenAccent,
                  ),
                ),
              ],
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      "${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.greenAccent,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      "${hijri.hDay} ${getTurkishHijriMonth(hijri.longMonthName)} ${hijri.hYear}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (diniGun != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          diniGun,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 18,
                  runSpacing: 14,
                  children: prayerTimes.entries.map((e) {
                    return Container(
                      width: 82,
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            e.key,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            e.value,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (gununSozu != null)
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.menu_book, color: Colors.green),
                      title: const Text(
                        "📖 Günün Sözü",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        "Bugünün sözünü okumak için dokunun",
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) {
                            return BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: Dialog(
                                backgroundColor: Colors.transparent,

                                child: Container(
                                  padding: const EdgeInsets.all(24),

                                  decoration: BoxDecoration(
                                    color: const Color(0xFF102027),
                                    borderRadius: BorderRadius.circular(24),

                                    border: Border.all(
                                      color: Colors.greenAccent.withOpacity(
                                        0.3,
                                      ),
                                      width: 1.2,
                                    ),
                                  ),

                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),

                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.greenAccent.withOpacity(
                                            0.12,
                                          ),
                                        ),

                                        child: TweenAnimationBuilder<double>(
                                          tween: Tween(begin: 0.8, end: 1.0),
                                          duration: const Duration(
                                            milliseconds: 600,
                                          ),
                                          builder: (context, value, child) {
                                            return Transform.scale(
                                              scale: value,
                                              child: child,
                                            );
                                          },
                                          child: const Icon(
                                            Icons.auto_awesome,
                                            color: Colors.greenAccent,
                                            size: 55,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 18),

                                      const Text(
                                        "📖 Günün Sözü",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.greenAccent,
                                        ),
                                      ),

                                      const SizedBox(height: 18),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.greenAccent.withOpacity(
                                            0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          gununSozu!['tur'] == 'hadis'
                                              ? "✨ HADİS-İ ŞERİF ✨"
                                              : gununSozu!['tur'] == 'ayet'
                                              ? "📖 AYET-İ KERİME 📖"
                                              : "🌿 HİKMETLİ SÖZ 🌿",
                                          style: const TextStyle(
                                            color: Colors.greenAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 16),
                                      Text(
                                        '"${gununSozu!['tam']}"',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          height: 1.6,
                                          color: Colors.white70,
                                        ),
                                      ),

                                      const SizedBox(height: 24),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          icon: const Icon(Icons.share),
                                          label: const Text(
                                            "Paylaş",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF1F1B2E,
                                            ),
                                            foregroundColor: Colors.greenAccent,

                                            side: const BorderSide(
                                              color: Colors.greenAccent,
                                              width: 1.5,
                                            ),

                                            minimumSize: const Size(
                                              double.infinity,
                                              58,
                                            ),

                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                          ),
                                          onPressed: () {
                                            Share.share(
                                              "${gununSozu!['tam']}\n\n🕌 Kıble Pusulası ve Namaz Vakitleri Uygulaması",
                                            );
                                          },
                                        ),
                                      ),

                                      const SizedBox(height: 10),
                                      SizedBox(
                                        width: double.infinity,

                                        child: ElevatedButton.icon(
                                          icon: const Icon(Icons.favorite),

                                          label: const Text(
                                            "KAPAT ",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),

                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.greenAccent,
                                            foregroundColor: Colors.black,
                                          ),

                                          onPressed: () {
                                            Navigator.pop(context);
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 15),

                                      const Text(
                                        "🕌 Kıble Pusulası ve Namaz Vakitleri",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              FlutterCompass.events == null
                  ? const Center(
                      child: Text(
                        "❌ Bu cihaz pusula sensörünü desteklemiyor",
                        textAlign: TextAlign.center,
                      ),
                    )
                  : StreamBuilder<CompassEvent>(
                      stream: FlutterCompass.events,
                      builder: (context, snapshot) {
                        if (!isActive) {
                          return const Center(child: Text("Arka planda"));
                        }
                        if (!snapshot.hasData ||
                            snapshot.data?.heading == null) {
                          return const Center(
                            child: Text(
                              "Pusula çalışmıyor.\nTelefonu 8 çizerek kalibre edin.",
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        if (qiblaDirection == null) {
                          return const SizedBox();
                        }
                        double rawHeading = snapshot.data!.heading ?? 0;
                        smoothedHeading =
                            smoothedHeading +
                            (rawHeading - smoothedHeading) * 0.08;
                        double qibla = qiblaDirection!;
                        double diff = (smoothedHeading - qibla).abs();
                        if (diff > 180) diff = 360 - diff;
                        bool isQibla = diff < 10;
                        if (isQibla && !kibleSesiCalindi) {
                          kibleSesiCalindi = true;
                          _audioPlayer.play(AssetSource('kible_bulundu.mp3'));
                        } else if (!isQibla) {
                          kibleSesiCalindi = false;
                        }
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // PUSULA + SAĞDA SCROLL İKONU - YAN YANA
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      if (isQibla)
                                        BoxShadow(
                                          color: Colors.greenAccent.withOpacity(
                                            0.5,
                                          ),
                                          blurRadius: 25,
                                          spreadRadius: 5,
                                        ),
                                    ],
                                  ),
                                  child: CustomPaint(
                                    size: Size(
                                      MediaQuery.of(context).size.width * 0.68,
                                      MediaQuery.of(context).size.width * 0.68,
                                    ),
                                    painter: CompassPainter(
                                      heading: smoothedHeading,
                                      qiblaDirection: qibla,
                                      isQibla: isQibla,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                GestureDetector(
                                  onTap: () {
                                    if (_showDownArrow) {
                                      _scrollController.animateTo(
                                        _scrollController
                                            .position
                                            .maxScrollExtent,
                                        duration: const Duration(
                                          milliseconds: 500,
                                        ),
                                        curve: Curves.easeInOut,
                                      );
                                    } else {
                                      _scrollController.animateTo(
                                        0,
                                        duration: const Duration(
                                          milliseconds: 500,
                                        ),
                                        curve: Curves.easeInOut,
                                      );
                                    }
                                  },
                                  child: _ScrollHintIcon(
                                    isDown: _showDownArrow,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 40),
                            Text(
                              isQibla
                                  ? "✔ KIBLE BULUNDU"
                                  : "KIBLE İÇİN TELEFONU ÇEVİR",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: isQibla
                                    ? Colors.greenAccent
                                    : Colors.white70,
                                shadows: isQibla
                                    ? [
                                        const Shadow(
                                          color: Colors.greenAccent,
                                          blurRadius: 5,
                                        ),
                                      ]
                                    : [],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  "📍 $cityName • Kıble Açısı ${qiblaDirection!.toStringAsFixed(0)}°",
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize:
                                        MediaQuery.of(context).size.width *
                                        0.032,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.6,
                                    color: isQibla
                                        ? Colors.greenAccent
                                        : Colors.white70,
                                    shadows: [
                                      Shadow(
                                        color: isQibla
                                            ? Colors.greenAccent.withOpacity(
                                                0.4,
                                              )
                                            : Colors.black45,
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Text(
                              "İletişim :",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: openMail,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.email,
                                      color: Colors.greenAccent,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        "cahitacar.dev@gmail.com",
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.greenAccent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: openInstagram,
                              child: Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.camera_alt,
                                      color: Colors.pinkAccent,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "@acardijitalpazarlama",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.pinkAccent,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _bannerAd != null
          ? SizedBox(
              width: double.infinity,
              height: 50,
              child: AdWidget(ad: _bannerAd!),
            )
          : null,
    );
  }
}

class _ScrollHintIcon extends StatefulWidget {
  final bool isDown;
  const _ScrollHintIcon({required this.isDown});

  @override
  State<_ScrollHintIcon> createState() => _ScrollHintIconState();
}

class _ScrollHintIconState extends State<_ScrollHintIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: 0,
      end: 10,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            0,
            widget.isDown ? _animation.value : -_animation.value,
          ),
          child: Icon(
            widget.isDown
                ? Icons.keyboard_double_arrow_down_rounded
                : Icons.keyboard_double_arrow_up_rounded,
            color: Colors.greenAccent,
            size: 32,
          ),
        );
      },
    );
  }
}

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
      radius - 8,
      Paint()
        ..color = Colors.white.withOpacity(0.03)
        ..style = PaintingStyle.fill,
    );
    final rect = Rect.fromCircle(center: center, radius: radius);

    final gradientPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.greenAccent, Colors.cyanAccent, Colors.greenAccent],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    canvas.drawCircle(center, radius, gradientPaint);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.greenAccent.withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    for (int i = 0; i < 360; i += 30) {
      final angle = (i - 90) * pi / 180;

      final x1 = center.dx + cos(angle) * (radius - 14);
      final y1 = center.dy + sin(angle) * (radius - 14);

      final x2 = center.dx + cos(angle) * (radius - 2);
      final y2 = center.dy + sin(angle) * (radius - 2);

      canvas.drawLine(
        Offset(x1, y1),
        Offset(x2, y2),
        Paint()
          ..color = Colors.white38
          ..strokeWidth = 2,
      );
    }
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

    canvas.drawCircle(
      center,
      12,
      Paint()
        ..color = Colors.white
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(center, 3, Paint()..color = Colors.greenAccent);
    final tp = TextPainter(
      text: TextSpan(
        text: "${heading.toStringAsFixed(0)}°",
        style: TextStyle(
          color: isQibla ? Colors.greenAccent : Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
          shadows: [
            Shadow(
              color: isQibla ? Colors.greenAccent : Colors.white24,
              blurRadius: 12,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    tp.layout();

    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy + 8));
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-heading * pi / 180);
    canvas.translate(-center.dx, -center.dy);
    drawTextDual(
      "N",
      "Kuzey",
      Offset(center.dx - 5, center.dy - radius + 10),
      Colors.red,
    );
    drawTextDual(
      "S",
      "Güney",
      Offset(center.dx - 10, center.dy + radius - 50),
      Colors.blue,
    );
    drawTextDual(
      "E",
      "Doğu",
      Offset(center.dx + radius - 50, center.dy - 15),
      Colors.green,
    );
    drawTextDual(
      "W",
      "Batı",
      Offset(center.dx - radius + 15, center.dy - 15),
      Colors.orange,
    );
    canvas.restore();
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isQibla
            ? [Colors.greenAccent, Colors.green]
            : [Color(0xFFFF6B6B), Color(0xFFD32F2F)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final path = Path();
    path.moveTo(center.dx, center.dy - radius + 28);

    path.lineTo(center.dx - 8, center.dy + 10);

    path.lineTo(center.dx + 8, center.dy + 10);
    path.close();
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate((-qiblaDirection + 180) * pi / 180);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
