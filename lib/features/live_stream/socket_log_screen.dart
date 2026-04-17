import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../controllers/chat_controller.dart';

/// Parses `timestamp | event | payload…` (payload may contain ` | `).
String? _parseSocketLogEventName(String line) {
  final first = line.indexOf(' | ');
  if (first == -1) return null;
  final second = line.indexOf(' | ', first + 1);
  if (second == -1) return null;
  return line.substring(first + 3, second).trim();
}

bool _isChatMessageLog(String line) {
  final ev = _parseSocketLogEventName(line);
  if (ev == null || ev.isEmpty) return false;
  // Inbound `chat:message` payloads, parse failures, and connection snapshot for this socket.
  return ev == 'chat:message' ||
      ev == 'CHAT_MESSAGE_SOCKET' ||
      ev.startsWith('chat:message:');
}

/// Live debug log showing only inbound `chat:message` lines.
class SocketLogScreen extends StatefulWidget {
  const SocketLogScreen({super.key});

  @override
  State<SocketLogScreen> createState() => _SocketLogScreenState();
}

class _SocketLogScreenState extends State<SocketLogScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Get.find<ChatController>().appendChatMessageSocketConnectionToLog();
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = Get.find<ChatController>();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        foregroundColor: Colors.white,
        title: Text('Socket chat logs', style: TextStyle(fontSize: 17.sp)),
        actions: [
          TextButton(
            onPressed: () {
              chat.clearSocketInboundLog();
            },
            child: Text(
              'Clear',
              style: TextStyle(
                color: Colors.orangeAccent,
                fontSize: 14.sp,
              ),
            ),
          ),
        ],
      ),
      body: Obx(() {
        final filtered = chat.socketInboundLog
            .where(_isChatMessageLog)
            .toList(growable: false);

        if (filtered.isEmpty) {
          return Center(
            child: Text(
              'No chat:message lines yet.\n'
              '(Includes CHAT_MESSAGE_SOCKET and chat:message:* debug lines.)',
              style: TextStyle(color: Colors.white54, fontSize: 14.sp),
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 16.h),
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            return Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: SelectableText(
                filtered[i],
                style: TextStyle(
                  fontSize: 11.sp,
                  color: const Color(0xFF9AE6B4),
                  fontFamily: 'monospace',
                  height: 1.35,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
