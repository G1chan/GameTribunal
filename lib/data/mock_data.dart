import 'package:flutter/foundation.dart';
import '../models/case_model.dart';
import '../models/user_model.dart';

final appStore = AppStore();
class CommentData { CommentData(this.name, this.message, this.side, {this.likes = 0, this.time = '방금 전'}); final String name, message, side, time; int likes; }
class AppStore extends ChangeNotifier {
  final user = AppUser();
  final cases = <GameCase>[
    GameCase(id: '1', game: '리그 오브 레전드', title: '바론 앞 한타, 이니시는 누구의 판단이었나?', status: '실시간 판정 중', leftRate: 62, rightRate: 38, comments: 248, live: true, description: '바론 시야가 없는 상황에서 무리하게 진입해 한타가 열렸습니다.'),
    GameCase(id: '2', game: '발로란트', title: '연막 밖으로 먼저 나온 듀얼리스트의 과실', status: '판정 진행 중', leftRate: 45, rightRate: 55, comments: 87),
    GameCase(id: '3', game: '오버워치 2', title: '궁극기가 있는데 후퇴한 탱커의 콜', status: '판정 종결', leftRate: 70, rightRate: 30, comments: 125),
  ];
  final comments = <CommentData>[CommentData('미니맵장인', '시야 체크 없이 들어간 쪽의 책임이 더 크다고 봅니다.', '신청인', likes: 32, time: '3분 전'), CommentData('판결의신', '서폿도 위험 핑을 주지 않아 공동 과실입니다.', '상대방', likes: 18, time: '8분 전')];
  void vote(GameCase item, int left) { item.leftRate = left; item.rightRate = 100 - left; user.votes++; notifyListeners(); }
  void addComment(String text, String side) { if (text.trim().isEmpty) return; comments.insert(0, CommentData(user.nickname, text.trim(), side)); notifyListeners(); }
  void addCase(GameCase item) { cases.insert(0, item); notifyListeners(); }
}
