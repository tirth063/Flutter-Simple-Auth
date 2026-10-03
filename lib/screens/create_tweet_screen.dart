import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:mainapp/providers/tweet_provider.dart';
import 'package:mainapp/models/tweet.dart';
import 'package:mainapp/providers/auth_provider.dart';

class CreateTweetScreen extends StatefulWidget {
  final Tweet? editTweet;

  const CreateTweetScreen({super.key, this.editTweet});

  @override
  State<CreateTweetScreen> createState() => _CreateTweetScreenState();
}

class _CreateTweetScreenState extends State<CreateTweetScreen> {
  late final TextEditingController _controller;
  final _picker = ImagePicker();
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _isSubmitting = false;
  int _charCount = 0;

  bool get _isEditing => widget.editTweet != null;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.editTweet?.content ?? "");
    _charCount = _controller.text.length;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _selectedImage = image;
        _selectedImageBytes = bytes;
      });
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _selectedImageBytes = null;
    });
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSubmitting = true);

    final tweetProvider = context.read<TweetProvider>();
    bool success;

    if (_isEditing) {
      success = await tweetProvider.updateTweet(
        uuid: widget.editTweet!.uuid,
        content: content,
      );
    } else {
      success = await tweetProvider.createTweet(
        content: content,
        imageFile: _selectedImage,
      );
    }

    setState(() => _isSubmitting = false);

    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? "Tweet updated." : "Tweet posted."),
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (mounted) {
      final errorMsg = _isEditing ? "Failed to update tweet." : "Failed to post tweet.";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? "Edit Tweet" : "New Tweet"),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isSubmitting || _charCount == 0 ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? "Save" : "Post"),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              maxLines: 5,
              maxLength: 280,
              autofocus: !_isEditing,
              onChanged: (value) => setState(() => _charCount = value.length),
              decoration: const InputDecoration(
                hintText: "What's happening?",
                border: InputBorder.none,
              ),
            ),
            if (_selectedImageBytes != null) ...[
              const SizedBox(height: 8),
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _selectedImageBytes!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: _removeImage,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              if (!_isEditing)
                IconButton(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image_outlined),
                  tooltip: "Add image",
                ),
              const Spacer(),
              Text(
                "$_charCount/280",
                style: TextStyle(
                  color: _charCount > 280 ? Colors.red : Colors.grey,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
