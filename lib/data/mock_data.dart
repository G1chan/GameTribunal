import 'package:flutter/foundation.dart';
import '../models/case_model.dart';
import '../models/user_model.dart';

final appStore = AppStore();

class CommentData {
  CommentData(
    this.name,
    this.message,
    this.side, {
    this.likes = 0,
    this.time = '방금 전',
  });

  final String name, message, side, time;
  int likes;
}

class AppStore extends ChangeNotifier {
  final user = AppUser();

  // 실제 Firestore 데이터를 사용하므로 로컬 더미 데이터는 모두 비워둡니다.
  final cases = <GameCase>[];
  final comments = <CommentData>[];

  void vote(GameCase item, int left) {
    item.leftRate = left;
    item.rightRate = 100 - left;
    user.votes++;
    notifyListeners();
  }

  void addComment(String text, String side) {
    if (text.trim().isEmpty) return;
    comments.insert(0, CommentData(user.nickname, text.trim(), side));
    notifyListeners();
  }

  void addCase(GameCase item) {
    cases.insert(0, item);
    notifyListeners();
  }
}