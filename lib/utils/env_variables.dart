import 'package:flutter_dotenv/flutter_dotenv.dart';

final devApiUrl = dotenv.get('DEV_BASE_URL');
final prodApiUrl = dotenv.get('PROD_BASE_URL');
