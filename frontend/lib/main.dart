import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/omnicare_theme.dart';
import 'services/api_service.dart';
import 'screens/patient_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set status bar to blend with the cream background
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  runApp(const OmniCareApp());
}

class OmniCareApp extends StatefulWidget {
  const OmniCareApp({super.key});

  @override
  State<OmniCareApp> createState() => _OmniCareAppState();
}

class _OmniCareAppState extends State<OmniCareApp> {
  late final ApiService _apiService;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OmniCare',
      debugShowCheckedModeBanner: false,
      theme: OmniCareTheme.theme,
      home: PatientScreen(apiService: _apiService),
    );
  }
}
