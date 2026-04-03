import 'dart:io';
import 'dart:convert';

void main() async {
  print("--- Testing Open-Meteo ---");
  // Kathmandu coords: 27.7172, 85.3240
  final weatherUrl = Uri.parse("https://api.open-meteo.com/v1/forecast?latitude=27.7172&longitude=85.3240&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto");
  try {
    final client = HttpClient();
    final req = await client.getUrl(weatherUrl);
    final res = await req.close();
    if (res.statusCode == 200) {
      final text = await res.transform(utf8.decoder).join();
      final data = json.decode(text);
      print("Weather success: ${data['daily']['time'].take(3)}");
    } else {
      print("Weather failed: ${res.statusCode}");
    }
    client.close();
  } catch (e) {
    print("Weather error: $e");
  }

  print("\n--- Testing ZenQuotes ---");
  final quoteUrl = Uri.parse("https://zenquotes.io/api/today");
  try {
    final client = HttpClient();
    final req = await client.getUrl(quoteUrl);
    final res = await req.close();
    if (res.statusCode == 200) {
      final text = await res.transform(utf8.decoder).join();
      final data = json.decode(text);
      print("Quote success: ${data[0]['q']} - ${data[0]['a']}");
    } else {
      print("Quote failed: ${res.statusCode}");
    }
  } catch (e) {
    print("Quote error: $e");
  }
  exit(0);
}
