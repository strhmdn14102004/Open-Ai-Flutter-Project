import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:openai_sasat/helper/dimension.dart';
import 'package:shimmer/shimmer.dart';

import 'api_key.dart'; // Import your api_key.dart file

void main() {
  runApp(const GenerativeAISample());
}

class GenerativeAISample extends StatelessWidget {
  const GenerativeAISample({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Open AI',
      home: ChatScreen(title: 'Open AI By Sasat'),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.title});

  final String title;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: ApiKey.apiKey.isNotEmpty
          ? const ChatWidget(apiKey: ApiKey.apiKey)
          : const Center(
              child: Text(
                'No API key found. Please provide an API Key using '
                "'--dart-define' to set the 'API_KEY' declaration.",
                textAlign: TextAlign.center,
              ),
            ),
    );
  }
}

class ChatWidget extends StatefulWidget {
  const ChatWidget({
    required this.apiKey,
    super.key,
  });

  final String apiKey;

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  late final GenerativeModel _model;
  late final ChatSession _chat;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFieldFocus = FocusNode();
  final List<({Image? image, String? text, bool fromUser, bool isLoading})>
      _generatedContent =
      <({Image? image, String? text, bool fromUser, bool isLoading})>[];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(
      model: 'gemini-1.5-flash-latest',
      apiKey: widget.apiKey,
    );
    _chat = _model.startChat();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 750),
        curve: Curves.easeOutCirc,
      ),
    );
  }

  Future<void> _sendChatMessage(String message) async {
    setState(() {
      _generatedContent
          .add((image: null, text: message, fromUser: true, isLoading: true));
    });

    try {
      final response = await _chat.sendMessage(
        Content.text("Bahasa Indonesia: $message"),
      );
      final text = response.text;
      _generatedContent
          .add((image: null, text: text, fromUser: false, isLoading: false));

      if (text == null) {
        _showError('No response from API.');
        return;
      } else {
        setState(() {
          _scrollDown();
        });
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      _textController.clear();
      setState(() {
        for (var i = 0; i < _generatedContent.length; i++) {
          if (_generatedContent[i].isLoading) {
            _generatedContent[i] = (
              image: _generatedContent[i].image,
              text: _generatedContent[i].text,
              fromUser: _generatedContent[i].fromUser,
              isLoading: false
            );
          }
        }
      });
      _textFieldFocus.requestFocus();
    }
  }

  Future<void> _sendImagePrompt(String message, List<File> images) async {
    setState(() {
      _generatedContent.addAll(images.map((file) => (
            image: Image.file(file),
            text: message,
            fromUser: true,
            isLoading: true,
          )));
    });

    try {
      final content = [
        Content.multi([
          TextPart("Bahasa Indonesia: $message"),
          ...images
              .map((file) => DataPart('image/jpeg', file.readAsBytesSync())),
        ])
      ];

      var response = await _model.generateContent(content);
      var text = response.text;
      _generatedContent
          .add((image: null, text: text, fromUser: false, isLoading: false));

      if (text == null) {
        _showError('No response from API.');
        return;
      } else {
        setState(() {
          _scrollDown();
        });
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      _textController.clear();
      setState(() {
        for (var i = 0; i < _generatedContent.length; i++) {
          if (_generatedContent[i].isLoading) {
            _generatedContent[i] = (
              image: _generatedContent[i].image,
              text: _generatedContent[i].text,
              fromUser: _generatedContent[i].fromUser,
              isLoading: false
            );
          }
        }
      });
      _textFieldFocus.requestFocus();
    }
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile>? pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles != null) {
        final images = pickedFiles.map((file) => File(file.path)).toList();
        _sendImagePrompt(_textController.text, images);
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Something went wrong'),
          content: SingleChildScrollView(
            child: SelectableText(message),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            )
          ],
        );
      },
    );
  }

  void _deleteMessage(int index) {
    setState(() {
      _generatedContent.removeAt(index);
    });
  }

  void _copyMessage(String content) {
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textFieldDecoration = InputDecoration(
      contentPadding: const EdgeInsets.all(15),
      hintText: 'Tanya sesuatu...',
      border: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _generatedContent.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Lottie.asset(
                          "assets/lottie/chat.json",
                          frameRate: const FrameRate(60),
                          width: Dimensions.size100 * 2,
                          repeat: true,
                        ),
                        Text(
                          "Pesan Tidak Tersedia\nAyo Mulai Percakapan...",
                          style: TextStyle(
                            fontSize: Dimensions.text20,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemBuilder: (context, idx) {
                      final content = _generatedContent[idx];
                      final messageText = content.text ?? '';
                      final messageImage =
                          content.image?.image.toString() ?? '';
                      final fullMessage = messageText.isNotEmpty
                          ? messageText
                          : messageImage.isNotEmpty
                              ? messageImage
                              : '';

                      return Dismissible(
                        key: Key(content.text ?? content.image.toString()),
                        direction: DismissDirection.startToEnd,
                        onDismissed: (direction) {
                          _deleteMessage(idx);
                        },
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: GestureDetector(
                          onTap: () => _copyMessage(fullMessage),
                          child: MessageWidget(
                            text: content.text,
                            image: content.image,
                            isFromUser: content.fromUser,
                            isLoading: content.isLoading,
                          ),
                        ),
                      );
                    },
                    itemCount: _generatedContent.length,
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 15),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    autofocus: true,
                    focusNode: _textFieldFocus,
                    decoration: textFieldDecoration,
                    controller: _textController,
                    onSubmitted: _sendChatMessage,
                  ),
                ),
                const SizedBox.square(dimension: 15),
                IconButton(
                  onPressed: _pickImages,
                  icon: Icon(
                    Icons.image,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    _sendChatMessage(_textController.text);
                  },
                  icon: Icon(
                    Icons.send,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MessageWidget extends StatelessWidget {
  const MessageWidget({
    super.key,
    this.image,
    this.text,
    required this.isFromUser,
    required this.isLoading,
  });

  final Image? image;
  final String? text;
  final bool isFromUser;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment:
          isFromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            decoration: BoxDecoration(
              color: isFromUser
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (text != null) SelectableText(text!),
                if (image != null) image!,
                if (isLoading)
                  Shimmer.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: Container(
                      width: double.infinity,
                      height: 20.0,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
