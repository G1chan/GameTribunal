import 'package:flutter_test/flutter_test.dart';
import 'package:game_tribunal/services/case_service.dart';
import 'package:game_tribunal/services/user_service.dart';

void main() {
  group('60:40 유효 판결 규칙 (CaseService.determineWinnerCounts)', () {
    test('최소 참여 인원 미달 시 치열한 논쟁(draw)으로 처리된다', () {
      expect(
        CaseService.determineWinnerCounts(leftVotes: 2, rightVotes: 0),
        'draw',
      );
      expect(
        CaseService.determineWinnerCounts(leftVotes: 0, rightVotes: 2),
        'draw',
      );
    });

    test('신청인 과실이 60% 이상이면 left 승리로 확정된다', () {
      expect(
        CaseService.determineWinnerCounts(leftVotes: 3, rightVotes: 2),
        'left',
      );
      expect(
        CaseService.determineWinnerCounts(leftVotes: 6, rightVotes: 4),
        'left',
      );
    });

    test('상대방 과실이 60% 이상이면 right 승리로 확정된다', () {
      expect(
        CaseService.determineWinnerCounts(leftVotes: 2, rightVotes: 3),
        'right',
      );
      expect(
        CaseService.determineWinnerCounts(leftVotes: 4, rightVotes: 6),
        'right',
      );
    });

    test('60:40 미만 접전이면 보류(draw) 처리된다', () {
      expect(
        CaseService.determineWinnerCounts(leftVotes: 5, rightVotes: 5),
        'draw',
      );
      expect(
        CaseService.determineWinnerCounts(leftVotes: 59, rightVotes: 41),
        'draw',
      );
    });
  });

  group('레벨업 경험치 공식 (UserProfile.computeLevelProgress)', () {
    test('0 XP 또는 음수 XP는 Lv.1 (0/100)로 계산된다', () {
      final zero = UserProfile.computeLevelProgress(0);
      expect(zero.level, 1);
      expect(zero.currentXp, 0);
      expect(zero.nextLevelXp, 100);

      final negative = UserProfile.computeLevelProgress(-50);
      expect(negative.level, 1);
      expect(negative.currentXp, 0);
    });

    test('누적 XP가 Lv*100 임계치를 넘을 때마다 레벨이 상승한다', () {
      // Lv.1 -> Lv.2 필요: 100
      final lv2 = UserProfile.computeLevelProgress(100);
      expect(lv2.level, 2);
      expect(lv2.currentXp, 0);
      expect(lv2.nextLevelXp, 200);

      // Lv.1(100) + Lv.2(200) = 300 -> Lv.3, 잔여 45 XP
      final lv3 = UserProfile.computeLevelProgress(345);
      expect(lv3.level, 3);
      expect(lv3.currentXp, 45);
      expect(lv3.nextLevelXp, 300);
    });
  });

  group('적중률 · 일일 미션 · 상위 티어 판별', () {
    test('유효 판결 참여 수가 기준 미만이면 적중률이 산정 중으로 표시된다', () {
      const profile = UserProfile(
        uid: 'u1',
        nickname: '배심원',
        email: 'a@b.com',
        favoriteGames: ['리그 오브 레전드'],
        xp: 50,
        level: 1,
        points: 10,
        totalVotes: 2,
        validJudgedCount: 2,
        hitCount: 2,
        onboardingCompleted: true,
      );

      expect(profile.accuracyRate, isNull);
      expect(profile.accuracyText, contains('산정 중'));
    });

    test('유효 판결 참여 수가 기준 이상이면 백분율 적중률을 계산한다', () {
      const profile = UserProfile(
        uid: 'u2',
        nickname: '대법관',
        email: 'a@b.com',
        favoriteGames: ['리그 오브 레전드'],
        xp: 4500,
        level: 20,
        points: 100,
        totalVotes: 10,
        validJudgedCount: 4,
        hitCount: 3,
        onboardingCompleted: true,
      );

      expect(profile.accuracyRate, closeTo(75.0, 0.001));
      expect(profile.accuracyText, '75.0%');
      expect(profile.title, '수석 판사');
    });

    test('일일 미션은 오늘 날짜 기준 3건 이상이고 미수령일 때만 수령 가능하다', () {
      final today = UserProfile.todayKey();

      final claimable = UserProfile(
        uid: 'u3',
        nickname: '열혈배심원',
        email: 'a@b.com',
        favoriteGames: const [],
        xp: 0,
        level: 1,
        points: 0,
        totalVotes: 3,
        validJudgedCount: 0,
        hitCount: 0,
        onboardingCompleted: true,
        dailyMissionDate: today,
        dailyVotesCount: PolicyConfig.dailyMissionTarget,
        dailyMissionClaimed: false,
      );
      expect(claimable.canClaimDailyMission, isTrue);

      const yesterday = UserProfile(
        uid: 'u4',
        nickname: '어제유저',
        email: 'a@b.com',
        favoriteGames: [],
        xp: 0,
        level: 1,
        points: 0,
        totalVotes: 3,
        validJudgedCount: 0,
        hitCount: 0,
        onboardingCompleted: true,
        dailyMissionDate: '2020-01-01',
        dailyVotesCount: 3,
        dailyMissionClaimed: false,
      );
      expect(yesterday.todayVotesCount, 0);
      expect(yesterday.canClaimDailyMission, isFalse);
    });

    test('플래티넘 이상만 상위 티어 배심원으로 분류된다', () {
      const gold = GameAccountInfo(gameId: 'A#KR1', tier: '골드');
      const plat = GameAccountInfo(gameId: 'B#KR1', tier: '플래티넘');
      const master = GameAccountInfo(gameId: 'C#KR1', tier: '마스터 이상');

      expect(gold.isHighTier, isFalse);
      expect(plat.isHighTier, isTrue);
      expect(master.isHighTier, isTrue);
    });
  });
}