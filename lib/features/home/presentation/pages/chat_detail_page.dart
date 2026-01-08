import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:buhay_link/features/jobs/data/repositories/chat_repository.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

// --- PACKAGES FOR DOWNLOADING ---
import 'package:gal/gal.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class ChatDetailPage extends StatefulWidget {
  final String receiverId;
  final String receiverName;

  const ChatDetailPage({
    super.key,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage>
    with WidgetsBindingObserver {
  final ChatRepository _chatRepository = ChatRepository();
  final TextEditingController _messageController = TextEditingController();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";
  final ScrollController _scrollController = ScrollController();

  // State
  String? _tappedMessageId;
  bool _isUploading = false;

  String get _chatRoomId {
    List<String> ids = [_currentUserId, widget.receiverId];
    ids.sort();
    return ids.join("_");
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _markMessagesAsSeen();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // --- SEEN STATUS LOGIC ---
  void _markMessagesAsSeen() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatRoomId)
        .collection('messages')
        .where('senderId', isEqualTo: widget.receiverId)
        .where('isSeen', isEqualTo: false)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isSeen': true});
    }
    await batch.commit();
  }

  // --- MESSAGE OPTIONS (DELETE & DOWNLOAD) ---
  void _showMessageOptions(
    String messageId,
    bool isMe,
    String type,
    String content,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Message Options",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // --- 1. DOWNLOAD OPTION (For Images/Files) ---
            if (type == 'image' || type == 'file')
              ListTile(
                leading: const Icon(Icons.download_rounded, color: Colors.blue),
                title: const Text("Save to Device"),
                onTap: () {
                  Navigator.pop(context);
                  if (type == 'image') {
                    _handleAttachmentClick(content, 'image');
                  } else {
                    List<String> parts = content.split('|');
                    _handleAttachmentClick(parts[0], 'file');
                  }
                },
              ),

            // --- 2. DELETE FOR ME ---
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.black87),
              title: const Text("Remove for you"),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(messageId, forEveryone: false);
              },
            ),

            // --- 3. UNSEND (Only if isMe) ---
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text(
                  "Unsend for everyone",
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(messageId, forEveryone: true);
                },
              ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMessage(
    String messageId, {
    required bool forEveryone,
  }) async {
    final docRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatRoomId)
        .collection('messages')
        .doc(messageId);

    if (forEveryone) {
      await docRef.delete();
    } else {
      await docRef.update({
        'deletedFor': FieldValue.arrayUnion([_currentUserId]),
      });
    }
  }

  // --- 1. HYBRID DOWNLOAD HANDLER ---
  Future<void> _handleAttachmentClick(String url, String type) async {
    try {
      if (type == 'location') {
        final Uri uri = Uri.parse(url);
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          throw 'Could not launch map';
        }
        return;
      }

      if (type == 'image') {
        setState(() => _isUploading = true);
        if (Platform.isAndroid) await Permission.storage.request();

        final tempDir = await getTemporaryDirectory();
        final path =
            '${tempDir.path}/img_${DateTime.now().millisecondsSinceEpoch}.jpg';

        await Dio().download(
          url,
          path,
          options: Options(headers: {'user-agent': 'Mozilla/5.0...'}),
        );
        await Gal.putImage(path, album: "BuhayLink");

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Image saved to Gallery!"),
              backgroundColor: Colors.green,
            ),
          );
        }
        setState(() => _isUploading = false);
      } else if (type == 'file') {
        await _downloadFile(url);
      }
    } catch (e) {
      debugPrint("Action Error: $e");
      if (mounted) {
        if (type == 'image') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Gallery save failed. Opening browser..."),
              backgroundColor: Colors.orange,
            ),
          );
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Download failed: $e. Opening browser..."),
              backgroundColor: Colors.orange,
            ),
          );
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        }
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // --- FILE DOWNLOADER HELPER ---
  Future<void> _downloadFile(String url) async {
    try {
      if (Platform.isAndroid) await Permission.storage.request();

      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      if (!dir.existsSync()) dir = await getExternalStorageDirectory();

      String ext = ".pdf";
      if (url.contains(".")) {
        String possibleExt = url.split('.').last;
        if (possibleExt.contains('?')) {
          possibleExt = possibleExt.split('?').first;
        }
        if (possibleExt.length < 5) ext = ".$possibleExt";
      }

      String fileName =
          "BuhayLink_File_${DateTime.now().millisecondsSinceEpoch}$ext";
      String savePath = "${dir?.path ?? ''}/$fileName";

      await Dio().download(
        url,
        savePath,
        options: Options(headers: {'user-agent': 'Mozilla/5.0...'}),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Saved to Downloads: $fileName"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      throw "Download failed: $e";
    }
  }

  // --- SENDING LOGIC ---
  void _sendMessage({String? type, String? content}) {
    final text = _messageController.text.trim();
    if (type == null && text.isNotEmpty) {
      _chatRepository.sendMessage(
        _chatRoomId,
        widget.receiverId,
        text,
        type: 'text',
      );
      _messageController.clear();
      _scrollToBottom();
    } else if (type != null && content != null) {
      _chatRepository.sendMessage(
        _chatRoomId,
        widget.receiverId,
        content,
        type: type,
      );
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // --- CLOUDINARY UPLOAD ---
  Future<String?> _uploadToCloudinary(File file) async {
    try {
      setState(() => _isUploading = true);
      String cloudName = "drhbxeggn";
      String uploadPreset = "buhaylink_preset";
      final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/auto/upload',
      );
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', file.path));
      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.toBytes();
        final jsonMap = jsonDecode(String.fromCharCodes(responseData));
        return jsonMap['secure_url'];
      } else {
        throw Exception("Status: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Upload failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      return null;
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // --- PICKERS & LOCATION ---
  void _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      imageQuality: 70,
    );
    if (image != null) {
      String? url = await _uploadToCloudinary(File(image.path));
      if (url != null) _sendMessage(type: 'image', content: url);
    }
  }

  void _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      String? url = await _uploadToCloudinary(file);
      if (url != null) {
        _sendMessage(type: 'file', content: "$url|${result.files.single.name}");
      }
    }
  }

  void _sendLocation() async {
    try {
      setState(() => _isUploading = true);
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw "Permission denied";
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      String mapUrl =
          "http://maps.google.com/?q=${position.latitude},${position.longitude}";
      _sendMessage(type: 'location', content: mapUrl);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("$e")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAttachmentOption(Icons.image, "Gallery", Colors.blue, () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                }),
                _buildAttachmentOption(
                  Icons.camera_alt,
                  "Camera",
                  Colors.pink,
                  () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                _buildAttachmentOption(
                  Icons.description,
                  "File",
                  Colors.orange,
                  () {
                    Navigator.pop(context);
                    _pickFile();
                  },
                ),
                _buildAttachmentOption(
                  Icons.location_on,
                  "Location",
                  Colors.green,
                  () {
                    Navigator.pop(context);
                    _sendLocation();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // --- CONTENT BUILDER (No Download Button) ---
  Widget _buildContent(String type, String content, bool isMe) {
    Color textColor = isMe ? Colors.white : Colors.black87;
    switch (type) {
      case 'image':
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            content,
            width: 200,
            fit: BoxFit.cover,
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return Container(
                width: 200,
                height: 150,
                color: Colors.grey[300],
                child: const Center(child: CircularProgressIndicator()),
              );
            },
          ),
        );

      case 'location':
        return GestureDetector(
          onTap: () => _handleAttachmentClick(content, 'location'),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on, color: isMe ? Colors.white : Colors.red),
              const SizedBox(width: 8),
              Text(
                "View Location",
                style: TextStyle(
                  color: textColor,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );

      case 'file':
        List<String> parts = content.split('|');
        return GestureDetector(
          onTap: () async {
            // Just open in browser when single tapped
            final Uri uri = Uri.parse(parts[0]);
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.insert_drive_file,
                color: isMe ? Colors.white : Colors.orange,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  parts.length > 1 ? parts[1] : "Attachment",
                  style: TextStyle(
                    color: textColor,
                    decoration: TextDecoration.underline,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );

      default:
        return Text(
          content.isEmpty ? "..." : content,
          style: TextStyle(color: textColor, fontSize: 15, height: 1.3),
        );
    }
  }

  // --- ONE SINGLE BUILD MESSAGE BUBBLE FUNCTION ---
  Widget _buildMessageBubble(
    String msgId,
    String content,
    String type,
    bool isMe,
    bool showAvatar,
    String time,
    bool isSeen,
    bool isLatest,
    String receiverPhotoUrl,
    String statusText,
  ) {
    bool isTapped = _tappedMessageId == msgId;
    return GestureDetector(
      onTap: () => setState(() => _tappedMessageId = isTapped ? null : msgId),
      onLongPress: () => _showMessageOptions(msgId, isMe, type, content),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 4, top: showAvatar ? 8 : 0),
            child: Row(
              mainAxisAlignment: isMe
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isMe && showAvatar)
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: receiverPhotoUrl.isNotEmpty
                        ? NetworkImage(receiverPhotoUrl)
                        : null,
                    child: receiverPhotoUrl.isEmpty
                        ? Text(
                            widget.receiverName.isNotEmpty
                                ? widget.receiverName[0].toUpperCase()
                                : "?",
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black54,
                            ),
                          )
                        : null,
                  ),
                if (!isMe && !showAvatar) const SizedBox(width: 28),
                if (!isMe) const SizedBox(width: 8),
                Flexible(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: type == 'image'
                        ? const EdgeInsets.all(4)
                        : const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                    decoration: BoxDecoration(
                      gradient: isMe && type != 'image'
                          ? const LinearGradient(
                              colors: [Color(0xFF2E7EFF), Color(0xFF0052CC)],
                            )
                          : null,
                      color: isMe ? null : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isMe ? 20 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _buildContent(type, content, isMe),
                  ),
                ),
              ],
            ),
          ),
          if (isTapped || (isMe && isLatest))
            Padding(
              padding: EdgeInsets.only(
                left: isMe ? 0 : 44,
                right: isMe ? 0 : 0,
                bottom: 8,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: isMe
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                children: [
                  Text(
                    time,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Text(
                      isSeen ? "Seen" : statusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSeen ? Colors.black54 : Colors.grey[400],
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      isSeen ? Icons.check_circle : Icons.check_circle_outline,
                      size: 12,
                      color: isSeen ? Colors.black54 : Colors.grey[400],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  // --- MAIN BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.receiverId)
          .snapshots(),
      builder: (context, userSnapshot) {
        String name = widget.receiverName;
        String photoUrl = "";
        bool isOnline = false;
        String lastSeenText = "Offline";

        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          final data = userSnapshot.data!.data() as Map<String, dynamic>;
          name = data['name'] ?? data['fullName'] ?? name;
          photoUrl = data['photoUrl'] ?? "";
          isOnline = data['isOnline'] ?? false;

          if (isOnline) {
            lastSeenText = "Active now";
          } else if (data['lastActive'] != null) {
            Timestamp ts = data['lastActive'];
            DateTime dt = ts.toDate();
            Duration diff = DateTime.now().difference(dt);
            if (diff.inMinutes < 60)
              lastSeenText = "Active ${diff.inMinutes}m ago";
            else if (diff.inHours < 24)
              lastSeenText = "Active ${diff.inHours}h ago";
            else
              lastSeenText = "Last seen ${DateFormat('MMM d').format(dt)}";
          }
        }

        String deliveryStatus = isOnline ? "Delivered" : "Sent";

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FB),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 1,
            leading: const BackButton(color: Colors.black),
            titleSpacing: 0,
            title: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.blue.shade100,
                      backgroundImage: photoUrl.isNotEmpty
                          ? NetworkImage(photoUrl)
                          : null,
                      child: photoUrl.isEmpty
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : "?",
                              style: TextStyle(
                                color: Colors.blue.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    if (isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        lastSeenText,
                        style: TextStyle(
                          color: isOnline ? Colors.green : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // --- REMOVED ACTIONS ICONS HERE AS REQUESTED ---
          ),
          body: Column(
            children: [
              if (_isUploading)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  color: Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text(
                        "Processing...",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _chatRepository.getMessagesStream(_chatRoomId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());
                    final messages = snapshot.data!.docs;

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final doc = messages[index];
                        final data = doc.data() as Map<String, dynamic>;

                        List<dynamic> deletedFor = data['deletedFor'] ?? [];
                        if (deletedFor.contains(_currentUserId))
                          return const SizedBox.shrink();

                        bool isMe = data['senderId'] == _currentUserId;
                        bool showAvatar = !isMe;
                        if (index > 0) {
                          final prevData =
                              messages[index - 1].data()
                                  as Map<String, dynamic>;
                          if (prevData['senderId'] == data['senderId'])
                            showAvatar = false;
                        }

                        Timestamp? time = data['timestamp'];
                        String formattedTime = time != null
                            ? DateFormat('h:mm a').format(time.toDate())
                            : "";
                        String content =
                            data['message'] ??
                            data['text'] ??
                            data['content'] ??
                            "";
                        bool isSeen = data['isSeen'] ?? false;
                        bool isLatest = (index == 0);

                        return _buildMessageBubble(
                          doc.id,
                          content,
                          data['type'] ?? 'text',
                          isMe,
                          showAvatar,
                          formattedTime,
                          isSeen,
                          isLatest,
                          photoUrl,
                          deliveryStatus,
                        );
                      },
                    );
                  },
                ),
              ),
              _buildInputBar(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.add_circle,
                color: Color(0xFF2E7EFF),
                size: 30,
              ),
              onPressed: _showAttachmentOptions,
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: "Type a message...",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _sendMessage(),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFF2E7EFF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
