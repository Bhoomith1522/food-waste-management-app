import 'package:flutter/material.dart';

class BotHelper extends StatefulWidget {
  final List<String> messages;

  BotHelper({required this.messages});

  @override
  _BotHelperState createState() => _BotHelperState();
}

class _BotHelperState extends State<BotHelper> {
  int index = 0;
  bool showMessage = true;

  void nextMessage() {
    if (index < widget.messages.length - 1) {
      setState(() {
        index++;
      });
    } else {
      setState(() {
        showMessage = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!showMessage) return SizedBox();

    return Positioned(
      bottom: 20,
      right: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 💬 MESSAGE BOX
          Container(
            padding: EdgeInsets.all(10),
            margin: EdgeInsets.only(bottom: 8),
            width: 220,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(color: Colors.black26, blurRadius: 5)
              ],
            ),
            child: Column(
              children: [
                Text(widget.messages[index]),
                SizedBox(height: 5),
                ElevatedButton(
                  onPressed: nextMessage,
                  child: Text("Next"),
                )
              ],
            ),
          ),

          // 🤖 BOT ICON
          CircleAvatar(
            radius: 25,
            backgroundColor: Colors.green,
            child: Icon(Icons.smart_toy, color: Colors.white),
          ),
        ],
      ),
    );
  }
}