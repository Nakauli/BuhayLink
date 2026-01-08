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

// --- PACKAGES FOR IMAGE DOWNLOADING (Kept these for the Gallery feature) ---
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

class _ChatDetailPageState extends State<ChatDetailPage> {
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

  // --- 1. HYBRID DOWNLOAD HANDLER ---
  Future<void> _handleAttachmentClick(String url, String type) async {
    try {
      // A. LOCATION: Open Map (Standard Browser)
      if (type == 'location') {
        final Uri uri = Uri.parse(url);
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          throw 'Could not launch map';
        }
        return;
      }

      // B. IMAGE: Save to Gallery (KEPT EXACTLY AS YOU REQUESTED)
      if (type == 'image') {
        setState(() => _isUploading = true); // Show loading

        if (Platform.isAndroid) {
          // Check storage permission for saving to gallery
          await Permission.storage.request();
        }

        final tempDir = await getTemporaryDirectory();
        final path =
            '${tempDir.path}/img_${DateTime.now().millisecondsSinceEpoch}.jpg';

        // Download image to temp folder first
        await Dio().download(
          url,
          path,
          options: Options(
            headers: {
              'user-agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
            },
          ),
        );

        // Save from temp folder to Gallery
        await Gal.putImage(path, album: "BuhayLink");

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Image saved to Gallery!"),
              backgroundColor: Colors.green,
            ),
          );
        }
        setState(() => _isUploading = false); // Stop loading
      }
      // C. FILE: Open in Chrome/Safari (BROWSER METHOD)
      else if (type == 'file') {
        final Uri uri = Uri.parse(url);

        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          throw 'Could not launch browser for file';
        }
      }
    } catch (e) {
      debugPrint("Action Error: $e");
      if (mounted) {
        // Fallback specifically for images failing
        if (type == 'image') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Gallery save failed: $e. Opening in browser..."),
              backgroundColor: Colors.orange,
            ),
          );
          // Fallback to browser if gallery fails
          final Uri uri = Uri.parse(url);
          launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Could not open: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
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
        final responseString = String.fromCharCodes(responseData);
        final jsonMap = jsonDecode(responseString);
        return jsonMap['secure_url'];
      } else {
        throw Exception("Status: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Upload failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // --- PICKERS ---
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

  // --- MESSAGE CONTENT BUILDER ---
  Widget _buildContent(String type, String content, bool isMe) {
    Color textColor = isMe ? Colors.white : Colors.black87;

    switch (type) {
      case 'image':
        return Stack(
          children: [
            ClipRRect(
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
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: InkWell(
                onTap: () => _handleAttachmentClick(content, 'image'),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.download,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        );

      case 'location':
        return GestureDetector(
          onTap: () => _handleAttachmentClick(content, 'location'),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on,
                  color: isMe ? Colors.white : Colors.red,
                ),
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
          ),
        );

      case 'file':
        List<String> parts = content.split('|');
        String url = parts[0];
        String name = parts.length > 1 ? parts[1] : "Attachment";
        return GestureDetector(
          onTap: () => _handleAttachmentClick(url, 'file'),
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
                  name,
                  style: TextStyle(
                    color: textColor,
                    decoration: TextDecoration.underline,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.open_in_browser,
                color: textColor.withOpacity(0.7),
                size: 20,
              ),
            ],
          ),
        );

      default:
        // Ensure content is not null when displayed
        return Text(
          content.isEmpty ? "..." : content,
          style: TextStyle(color: textColor, fontSize: 15, height: 1.3),
        );
    }
  }

  // --- BUBBLE WRAPPER ---
  Widget _buildMessageBubble(
    String msgId,
    String content,
    String type,
    bool isMe,
    bool showAvatar,
    String time,
  ) {
    bool isTapped = _tappedMessageId == msgId;

    return GestureDetector(
      onTap: () => setState(() => _tappedMessageId = isTapped ? null : msgId),
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
                if (!isMe) ...[
                  if (showAvatar)
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.grey[300],
                      child: Text(
                        widget.receiverName.isNotEmpty
                            ? widget.receiverName[0].toUpperCase()
                            : "?",
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black54,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 28),
                  const SizedBox(width: 8),
                ],
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
          if (isTapped)
            Padding(
              padding: EdgeInsets.only(
                left: isMe ? 0 : 44,
                right: isMe ? 0 : 0,
                bottom: 8,
              ),
              child: Text(
                time,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- INPUT BAR ---
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

  PreferredSizeWidget _buildFunctionalAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      shadowColor: Colors.grey.withOpacity(0.1),
      leading: const BackButton(color: Colors.black),
      titleSpacing: 0,
      title: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.receiverId)
            .snapshots(),
        builder: (context, snapshot) {
          String name = widget.receiverName;
          String photoUrl = "";
          bool isVerified = false;
          bool isOnline = false;
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            name = data['name'] ?? data['fullName'] ?? name;
            photoUrl = data['photoUrl'] ?? "";
            isVerified = data['isVerified'] == true;
            isOnline = data['isOnline'] ?? false;
          }
          return Row(
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified,
                            color: Colors.green,
                            size: 14,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      isOnline ? "Active now" : "Offline",
                      style: TextStyle(
                        color: isOnline ? Colors.green : Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.call, color: Color(0xFF2E7EFF)),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.videocam, color: Color(0xFF2E7EFF)),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.info_outline, color: Colors.black54),
          onPressed: () {},
        ),
      ],
    );
  }

  // --- THE BUILD METHOD IS HERE ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: _buildFunctionalAppBar(),
      body: Column(
        children: [
          // LOADING INDICATOR
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

          // 1. MESSAGES LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatRepository.getMessagesStream(_chatRoomId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true, // Newest messages at the bottom
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final doc = messages[index];
                    final data = doc.data() as Map<String, dynamic>;
                    bool isMe = data['senderId'] == _currentUserId;

                    bool showAvatar = !isMe;
                    if (index > 0) {
                      final prevData =
                          messages[index - 1].data() as Map<String, dynamic>;
                      if (prevData['senderId'] == data['senderId']) {
                        showAvatar = false;
                      }
                    }

                    Timestamp? time = data['timestamp'];
                    String formattedTime = "";
                    if (time != null) {
                      final dt = time.toDate();
                      formattedTime = DateFormat('h:mm a').format(dt);
                    }

                    // --- FIX: Check for 'message', 'text', OR 'content' ---
                    String content =
                        data['message'] ??
                        data['text'] ??
                        data['content'] ??
                        "";

                    return _buildMessageBubble(
                      doc.id,
                      content, // Passing the reliably found content
                      data['type'] ?? 'text',
                      isMe,
                      showAvatar,
                      formattedTime,
                    );
                  },
                );
              },
            ),
          ),

          // 2. INPUT BAR
          _buildInputBar(),
        ],
      ),
    );
  }
}
