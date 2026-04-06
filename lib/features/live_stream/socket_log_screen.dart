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
  return ev == 'chat:message';
}

/// Live debug log: **chat:message socket** connection status at top; list shows only
/// inbound `chat:message` lines ([ChatController.socketInboundLog]).
class SocketLogScreen extends StatefulWidget {
  const SocketLogScreen({super.key});

  @override
  State<SocketLogScreen> createState() => _SocketLogScreenState();
}

class _SocketLogScreenState extends State<SocketLogScreen> {
  final TextEditingController _search = TextEditingController();
  final RxString _searchRx = ''.obs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Get.find<ChatController>().appendChatMessageSocketConnectionToLog();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Widget _socketDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112.w,
            child: Text(
              label,
              style: TextStyle(color: Colors.white54, fontSize: 11.sp),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                color: const Color(0xFF9AE6B4),
                fontSize: 11.sp,
                fontFamily: 'monospace',
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chat = Get.find<ChatController>();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        foregroundColor: Colors.white,
        title: Text('Chat & activity log', style: TextStyle(fontSize: 17.sp)),
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 6.h),
            child: Obx(() {
              chat.isConnected.value;
              chat.platform.value;
              final d = chat.chatMessageSocketConnectionDetails;
              final connected = d['transport_connected'] == true;
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF121A14),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: const Color(0xFF2D5A3D)),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 10.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.forum_outlined,
                            color: const Color(0xFF68D391),
                            size: 20.sp,
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              'chat:message socket (Socket.IO)',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13.sp,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                chat.appendChatMessageSocketConnectionToLog(),
                            child: Text(
                              'Log line',
                              style: TextStyle(fontSize: 12.sp),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        '${d['api_doc_reference']}',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 10.sp,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 10.h),
                      _socketDetailRow(
                        '§5 Connection',
                        'transports: ${d['transports']}',
                      ),
                      _socketDetailRow(
                        'Auth (handshake)',
                        '${d['handshake_auth']}\n${d['handshake_header']}',
                      ),
                      _socketDetailRow(
                        'Token fingerprint',
                        '${d['access_token_fingerprint']}',
                      ),
                      _socketDetailRow('Base URL', '${d['base_url']}'),
                      _socketDetailRow(
                        'Socket.IO path',
                        '${d['socket_io_path']}',
                      ),
                      _socketDetailRow(
                        'Transport',
                        connected ? 'connected' : 'disconnected',
                      ),
                      _socketDetailRow(
                        'Session id',
                        '${d['socket_io_session_id']}',
                      ),
                      _socketDetailRow(
                        'UI platform',
                        chat.platform.value,
                      ),
                      _socketDetailRow(
                        'After connect',
                        '${d['client_emits_after_connect']}',
                      ),
                      SizedBox(height: 8.h),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 8.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          'Matches doc: ${d['implements_transports_per_doc'] == true ? '✓' : '✗'} websocket+polling  ·  '
                          '${d['implements_auth_per_doc'] == true ? '✓' : '✗'} auth.token + Bearer  ·  '
                          '${d['listens_for_chat_message'] == true ? '✓' : '✗'} listens chat:message',
                          style: TextStyle(
                            color: const Color(0xFFC6F6D5),
                            fontSize: 10.sp,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 8.h),
            child: TextField(
              controller: _search,
              onChanged: (v) => _searchRx.value = v,
              style: TextStyle(color: Colors.white, fontSize: 14.sp),
              decoration: InputDecoration(
                hintText: 'Search chat:message & activity:event…',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 13.sp),
                filled: true,
                fillColor: const Color(0xFF2C2C2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14.w,
                  vertical: 12.h,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.white54,
                  size: 22.sp,
                ),
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              final q = _searchRx.value.trim().toLowerCase();
              final base = chat.socketInboundLog
                  .where(_isChatMessageLog)
                  .toList(growable: false);
              final filtered = q.isEmpty
                  ? base
                  : base
                      .where((e) => e.toLowerCase().contains(q))
                      .toList(growable: false);

              if (filtered.isEmpty) {
                return Center(
                  child: Text(
                    q.isEmpty
                        ? 'No chat:message lines yet.'
                        : 'No matches.',
                    style: TextStyle(color: Colors.white54, fontSize: 14.sp),
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 16.h),
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
          ),
        ],
      ),
    );
  }
}
