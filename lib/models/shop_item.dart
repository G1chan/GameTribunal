import 'package:flutter/material.dart';

enum ShopItemCategory { consumable, title }

class ShopItem {
  const ShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.assetPath,
    required this.fallbackIcon,
    required this.accentColor,
    this.badgeText,
  });

  final String id;
  final String name;
  final String description;
  final int price;
  final ShopItemCategory category;
  final String assetPath;
  final IconData fallbackIcon;
  final Color accentColor;
  final String? badgeText;

  bool get isTitle => category == ShopItemCategory.title;
}

class ShopCatalog {
  ShopCatalog._();

  static const String nicknameTicketId = 'ticket_nickname';
  static const String caseBoostId = 'ticket_case_boost';
  static const String titleHawkId = 'title_hawk';
  static const String titleJudgeId = 'title_judge';
  static const String titleChiefId = 'title_chief';

  static const List<ShopItem> items = [
    ShopItem(
      id: nicknameTicketId,
      name: '닉네임 변경권',
      description: '개인정보 및 계정 설정에서 배심원 닉네임을 1회 변경할 수 있습니다.',
      price: 30,
      category: ShopItemCategory.consumable,
      assetPath: 'assets/images/shop/nickname_ticket.png',
      fallbackIcon: Icons.badge_outlined,
      accentColor: Color(0xFF0EA5E9),
    ),
    ShopItem(
      id: caseBoostId,
      name: '긴급 재판 부스트권',
      description: '내가 제보한 사건에 사용 시 24시간 동안 홈 피드 최상단에 긴급 판정으로 노출됩니다.',
      price: 50,
      category: ShopItemCategory.consumable,
      assetPath: 'assets/images/shop/case_boost.png',
      fallbackIcon: Icons.rocket_launch_rounded,
      accentColor: Color(0xFFF97316),
    ),
    ShopItem(
      id: titleHawkId,
      name: '칭호 · 예리한 매의 눈',
      description: '프로필, 랭킹, 실시간 토론 닉네임 옆에 전용 에메랄드 칭호 배지가 표시됩니다.',
      price: 40,
      category: ShopItemCategory.title,
      assetPath: 'assets/images/shop/title_hawk.png',
      fallbackIcon: Icons.visibility_rounded,
      accentColor: Color(0xFF10B981),
      badgeText: '예리한 매의 눈',
    ),
    ShopItem(
      id: titleJudgeId,
      name: '칭호 · 솔로랭크 판사',
      description: '프로필, 랭킹, 실시간 토론 닉네임 옆에 전용 사파이어 칭호 배지가 표시됩니다.',
      price: 60,
      category: ShopItemCategory.title,
      assetPath: 'assets/images/shop/title_judge.png',
      fallbackIcon: Icons.gavel_rounded,
      accentColor: Color(0xFF2563EB),
      badgeText: '솔로랭크 판사',
    ),
    ShopItem(
      id: titleChiefId,
      name: '칭호 · 명예 대법관',
      description: '최고 등급의 황금 칭호 배지로 모든 화면에서 시선을 사로잡습니다.',
      price: 100,
      category: ShopItemCategory.title,
      assetPath: 'assets/images/shop/title_chief.png',
      fallbackIcon: Icons.workspace_premium_rounded,
      accentColor: Color(0xFFD97706),
      badgeText: '명예 대법관',
    ),
  ];

  static ShopItem? findById(String? id) {
    if (id == null) return null;
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }
}