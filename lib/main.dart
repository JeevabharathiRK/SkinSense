import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart'; // Import this for Clipboard functionality
import 'package:flutter/gestures.dart'; // For handling links in markup

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: "AIzaSyD4z04My8gjYjRCCKep3ebYsanbrlUCMYc",
      appId: "1:1234567890:web:abcdef123456",
      messagingSenderId: "1234567890",
      projectId: "skinsense2025",
      databaseURL: "https://skinsense2025-default-rtdb.asia-southeast1.firebasedatabase.app",
    ),
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SkinSense',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: BottomNavExample(),
    );
  }
}

class ChatPage extends StatefulWidget {
  final Map<String, dynamic> sensorData;
  final List<Map<String, String>> messages; // Persistent chat messages

  ChatPage({required this.sensorData, required this.messages});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();

  // Function to parse markup and return a list of TextSpans
  List<TextSpan> parseMarkup(String text) {
    final RegExp markupRegex = RegExp(r'(\*.*?\*|_.*?_|\~.*?\~|`.*?`|https?:\/\/[^\s]+)');
    final matches = markupRegex.allMatches(text);
    final spans = <TextSpan>[];

    int lastMatchEnd = 0;

    for (final match in matches) {
      // Add plain text before the match
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start)));
      }

      final matchText = match.group(0)!;

      // Handle different markup styles
      if (matchText.startsWith('*') && matchText.endsWith('*')) {
        spans.add(TextSpan(
          text: matchText.substring(1, matchText.length - 1),
          style: TextStyle(fontWeight: FontWeight.bold),
        ));
      } else if (matchText.startsWith('_') && matchText.endsWith('_')) {
        spans.add(TextSpan(
          text: matchText.substring(1, matchText.length - 1),
          style: TextStyle(fontStyle: FontStyle.italic),
        ));
      } else if (matchText.startsWith('~') && matchText.endsWith('~')) {
        spans.add(TextSpan(
          text: matchText.substring(1, matchText.length - 1),
          style: TextStyle(decoration: TextDecoration.lineThrough),
        ));
      } else if (matchText.startsWith('`') && matchText.endsWith('`')) {
        spans.add(TextSpan(
          text: matchText.substring(1, matchText.length - 1),
          style: TextStyle(fontFamily: 'monospace', backgroundColor: Colors.grey[200]),
        ));
      } else if (matchText.startsWith('http')) {
        spans.add(TextSpan(
          text: matchText,
          style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              // Handle link tap (e.g., open in browser)
              print('Tapped on link: $matchText');
            },
        ));
      }

      lastMatchEnd = match.end;
    }

    // Add remaining plain text after the last match
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd)));
    }

    return spans;
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    // Add the user's message to the chat
    setState(() {
      widget.messages.add({"role": "user", "content": message});
    });

    // Clear the input field
    _controller.clear();

    // Prepare the payload for Groq Cloud API
    final payload = {
      "messages": [
        {"role": "system", "content": "You are SkinSense, a smart assistant. Help users by analyzing sensor data like UV Index, VOC, heart rate, and suggest preventive skincare and health tips accordingly."},
        ...widget.messages // Include the entire chat history
      ],
      "model": "llama3-8b-8192",
      "temperature": 1,
      "max_completion_tokens": 1024,
      "top_p": 1,
      "stream": false
    };

    // Send the message to Groq Cloud API
    try {
      final response = await http.post(
        Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
        headers: {
          "Authorization": "Bearer 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",
          "Content-Type": "application/json",
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final botResponse = data["choices"]?[0]?["message"]?["content"] ?? "No response from server.";

        // Add the bot's response to the chat
        setState(() {
          widget.messages.add({"role": "assistant", "content": botResponse});
        });
      } else {
        setState(() {
          widget.messages.add({"role": "assistant", "content": "Error: Unable to fetch response."});
        });
      }
    } catch (e) {
      setState(() {
        widget.messages.add({"role": "assistant", "content": "Error: $e"});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Chat with SkinSense Bot")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: widget.messages.length,
              itemBuilder: (context, index) {
                final message = widget.messages[index];
                final isUser = message["role"] == "user";
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue[400] : Colors.blue[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(color: Colors.black), // Default text style
                        children: parseMarkup(message["content"] ?? ""),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Type your message...",
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue), // Set border color to blue
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue), // Highlight color when focused
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () => _sendMessage(_controller.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BottomNavExample extends StatefulWidget {
  @override
  _BottomNavExampleState createState() => _BottomNavExampleState();
}

class _BottomNavExampleState extends State<BottomNavExample> {
  int _currentIndex = 0;
  Map<String, dynamic> sensorData = {}; // Store sensor data here
  final List<Map<String, String>> _messages = []; // Persistent chat messages

  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    // Fetch sensor data from HomePage
    sensorData = {}; // Replace with actual sensor data fetching logic
    _pages.addAll([
      HomePage(),
      ChatPage(sensorData: sensorData, messages: _messages), // Pass sensorData and messages to ChatPage
      Center(child: Text('🧪 You are on a testing profile', style: TextStyle(fontSize: 24))),
    ]);
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('SkinSense'),
            Text('Today', style: TextStyle(fontSize: 14, color: Colors.blue)),
          ],
        ),
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        selectedItemColor: Colors.blue, // Highlight color for selected item
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final databaseRef = FirebaseDatabase.instance.ref("SkinSense/sensor");
  Map<String, dynamic> sensorData = {};

  @override
  void initState() {
    super.initState();
    databaseRef.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data is Map) {
        setState(() => sensorData = Map<String, dynamic>.from(data));
      } else {
        setState(() => sensorData = {});
      }
    });
  }

  Widget sensorTile(String label, num value, num max, Color color) {
    double percent = (value / max).clamp(0.0, 1.0).toDouble();

    // Determine the color dynamically based on the label and value
    Color dynamicColor = getDynamicColor(label, value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("$label :", style: TextStyle(fontWeight: FontWeight.bold)),
        Stack(
          children: [
            Container(
              width: double.infinity,
              height: 24,
              color: dynamicColor.withOpacity(0.2),
            ),
            Container(
              width: MediaQuery.of(context).size.width * percent,
              height: 24,
              color: dynamicColor,
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.only(left: 8),
              child: Text("$value", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        SizedBox(height: 10),
      ],
    );
  }

  // Function to determine the color dynamically based on the label and value
  Color getDynamicColor(String label, num value) {
    switch (label) {
      case "UV Index":
        if (value <= 2) return Colors.green;
        if (value <= 5) return Colors.amber;
        return Colors.red;

      case "Co2 (ppm)":
        if (value < 700) return Colors.green;
        if (value <= 1100) return Colors.amber;
        return Colors.red;

      case "VOC (µg/m³)":
        if (value < 100) return Colors.green;
        if (value <= 300) return Colors.amber;
        return Colors.red;

      case "Heart Rate (bpm)":
        if (value >= 60 && value <= 100) return Colors.green; // Normal range
        if (value < 60 || value > 100) return Colors.red; // Abnormal range
        return Colors.amber; // Edge case (optional)

      case "Oxygen Saturation (%)":
        if (value >= 95) return Colors.green; // Normal range
        if (value >= 90) return Colors.amber; // Slightly low
        return Colors.red; // Critical

      case "Environment Temperature (°C)":
        if (value < 30) return Colors.green;
        if (value <= 35) return Colors.amber;
        return Colors.red;

      default:
        return Colors.grey; // Default color for unknown labels
    }
  }

  @override
  Widget build(BuildContext context) {
    int uvRaw = sensorData['GUVA-S12SD']?['raw'] ?? 0;
    int uvIndex = (uvRaw * 10 / 127).round();

    int vocRaw = sensorData['MQ135']?['raw'] ?? 0;
    int voc = (vocRaw ~/ 25); // approximate conversion to µg/m³

    int heartRate = sensorData['MAX30102']?['heartRate'] ?? 0;
    int spo2 = sensorData['MAX30102']?['SPO2'] ?? 0;

    int temp = sensorData['DHT11']?['temperature'] ?? 0;

    // Prepare the sensor data as a string for copying
    String sensorDataString = """
UV Index: $uvIndex
Co2 (ppm): ${sensorData['Co2'] ?? 'N/A'}
VOC (µg/m³): $voc
Heart Rate (bpm): $heartRate
Oxygen Saturation (%): $spo2
Environment Temperature (°C): $temp
""";

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Real-time Sensor Readings", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          sensorTile("UV Index", uvIndex, 10, Colors.amber),
          sensorTile("Co2 (ppm)", 600, 2000, Colors.green),
          sensorTile("VOC (µg/m³)", voc, 700, Colors.red),
          sensorTile("Heart Rate (bpm)", heartRate, 100, Colors.green),
          sensorTile("Oxygen Saturation (%)", spo2, 100, Colors.amber),
          sensorTile("Environment Temperature (°C)", temp, 46, Colors.amber),
          SizedBox(height: 20),
          Text("Hint:", style: TextStyle(fontWeight: FontWeight.bold)),
          Row(children: [
            colorDot(Colors.green), Text(" Safe  "),
            colorDot(Colors.amber), Text(" Need Protection  "),
            colorDot(Colors.red), Text(" Hazardous"),
          ]),
          SizedBox(height: 20),
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, // Set button background color to blue
                foregroundColor: Colors.white, // Set button text color to white
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: sensorDataString));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Sensor data copied to clipboard!")),
                );
              },
              child: Text("Copy Data"),
            ),
          ),
        ],
      ),
    );
  }

  Widget colorDot(Color color) => Container(width: 12, height: 12, margin: EdgeInsets.only(right: 6), decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}
