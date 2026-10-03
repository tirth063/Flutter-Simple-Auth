import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:mainapp/models/tweet.dart';
import 'package:mainapp/services/tweet_service.dart';

class TweetProvider extends ChangeNotifier {
  TweetService _tweetService;
  List<Tweet> _tweets = [];
  bool _isLoading = false;
  String? _error;

  TweetProvider(this._tweetService);

  void updateService(TweetService service) {
    _tweetService = service;
  }

  List<Tweet> get tweets => _tweets;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadTweets() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _tweets = await _tweetService.getTweets();
    } catch (e) {
      _error = "Failed to load tweets.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Tweet?> getTweetByUuid(String uuid) async {
    try {
      return await _tweetService.getTweetByUuid(uuid);
    } catch (e) {
      return null;
    }
  }

  Future<bool> createTweet({required String content, XFile? imageFile}) async {
    _error = null;
    notifyListeners();
    try {
      final tweet = await _tweetService.createTweet(
        content: content,
        imageFile: imageFile,
      );
      _tweets.insert(0, tweet);
      notifyListeners();
      return true;
    } catch (e) {
      _error = "Failed to create tweet.";
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateTweet({required String uuid, required String content}) async {
    _error = null;
    notifyListeners();
    try {
      final updated = await _tweetService.updateTweet(uuid: uuid, content: content);
      final index = _tweets.indexWhere((t) => t.uuid == uuid);
      if (index != -1) {
        _tweets[index] = updated;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = "Failed to update tweet.";
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTweet(String uuid) async {
    _error = null;
    notifyListeners();
    try {
      await _tweetService.deleteTweet(uuid);
      _tweets.removeWhere((t) => t.uuid == uuid);
      notifyListeners();
      return true;
    } catch (e) {
      _error = "Failed to delete tweet.";
      notifyListeners();
      return false;
    }
  }
}
