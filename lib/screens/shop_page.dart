import 'package:flutter/material.dart';
import '../models/shop_item.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_header.dart';
import '../widgets/user_avatar.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  bool _isProcessing = false;

  Future<void> _buyItem(UserProfile profile, ShopItem item) async {
    if (_isProcessing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('${item.name} 구매'),
        content: Text(
          '${item.price} P를 사용해 구매할까요?\n(구매 후 잔여 포인트: ${profile.points - item.price} P · 명예의 전당 누적 순위는 유지됩니다)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            child: Text('${item.price} P 결제'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      await UserService.instance.purchaseShopItem(
        uid: profile.uid,
        item: item,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.name} 구매 완료! 내 보관함에서 확인하세요.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _toggleEquipTitle(UserProfile profile, String? titleId) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await UserService.instance.equipTitle(
        uid: profile.uid,
        titleId: titleId,
      );
      if (!mounted) return;
      final label = titleId == null
          ? '칭호 장착을 해제했습니다.'
          : '${ShopCatalog.findById(titleId)?.badgeText ?? '칭호'}을(를) 장착했습니다!';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(label)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('칭호 변경 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        appBar: AppHeader(title: '포인트 상점', back: true),
        body: Center(child: Text('로그인이 필요합니다.')),
      );
    }

    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab.clamp(0, 1),
      child: StreamBuilder<UserProfile?>(
        stream: UserService.instance.watchUser(uid),
        builder: (context, snapshot) {
          final profile = snapshot.data;
          if (snapshot.connectionState == ConnectionState.waiting &&
              profile == null) {
            return const Scaffold(
              appBar: AppHeader(title: '포인트 상점', back: true),
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (profile == null) {
            return const Scaffold(
              appBar: AppHeader(title: '포인트 상점', back: true),
              body: Center(child: Text('유저 정보를 불러올 수 없습니다.')),
            );
          }

          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
              ),
              title: const Text(
                '포인트 상점 & 보관함',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              bottom: const TabBar(
                indicatorColor: AppColors.red,
                labelColor: AppColors.red,
                unselectedLabelColor: AppColors.muted,
                labelStyle: TextStyle(fontWeight: FontWeight.w900),
                tabs: [
                  Tab(text: '포인트 상점'),
                  Tab(text: '내 보관함'),
                ],
              ),
            ),
            body: Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.field,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      LevelUserAvatar(
                        level: profile.level,
                        photoUrl: profile.photoUrl,
                        radius: 22,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '사용 가능 포인트',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              '${profile.points} P',
                              style: const TextStyle(
                                color: Color(0xFFFFC84D),
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '명예의 전당 누적 포인트: ${profile.totalEarnedPoints} P (차감 안 됨)',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _ShopCatalogTab(
                        profile: profile,
                        isProcessing: _isProcessing,
                        onBuy: (item) => _buyItem(profile, item),
                      ),
                      _InventoryTab(
                        profile: profile,
                        isProcessing: _isProcessing,
                        onEquipTitle: (id) => _toggleEquipTitle(profile, id),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ShopCatalogTab extends StatelessWidget {
  const _ShopCatalogTab({
    required this.profile,
    required this.isProcessing,
    required this.onBuy,
  });

  final UserProfile profile;
  final bool isProcessing;
  final ValueChanged<ShopItem> onBuy;

  @override
  Widget build(BuildContext context) {
    final consumables = ShopCatalog.items
        .where((i) => i.category == ShopItemCategory.consumable)
        .toList();
    final titles = ShopCatalog.items
        .where((i) => i.category == ShopItemCategory.title)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      children: [
        const Text(
          '기능성 아이템',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        ...consumables.map(
          (item) {
            final count = item.id == ShopCatalog.nicknameTicketId
                ? profile.nicknameTickets
                : profile.boostTickets;
            return _ShopItemCard(
              item: item,
              canAfford: profile.points >= item.price,
              alreadyOwned: false,
              ownedCount: count,
              isProcessing: isProcessing,
              onBuy: () => onBuy(item),
            );
          },
        ),
        const SizedBox(height: 16),
        const Text(
          '특별 배심원 칭호',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        ...titles.map(
          (item) {
            final owned = profile.ownedTitles.contains(item.id);
            return _ShopItemCard(
              item: item,
              canAfford: profile.points >= item.price,
              alreadyOwned: owned,
              ownedCount: 0,
              isProcessing: isProcessing,
              onBuy: () => onBuy(item),
            );
          },
        ),
      ],
    );
  }
}

class _ShopItemCard extends StatelessWidget {
  const _ShopItemCard({
    required this.item,
    required this.canAfford,
    required this.alreadyOwned,
    required this.ownedCount,
    required this.isProcessing,
    required this.onBuy,
  });

  final ShopItem item;
  final bool canAfford;
  final bool alreadyOwned;
  final int ownedCount;
  final bool isProcessing;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShopItemThumbnail(item: item, size: 68),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (ownedCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.redPale,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '보유 $ownedCount장',
                          style: const TextStyle(
                            color: AppColors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),
                if (item.isTitle) ...[
                  const SizedBox(height: 5),
                  UserTitleBadge(titleItem: item, compact: true),
                ],
                const SizedBox(height: 5),
                Text(
                  item.description,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      '${item.price} P',
                      style: const TextStyle(
                        color: AppColors.red,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: (alreadyOwned || !canAfford || isProcessing)
                          ? null
                          : onBuy,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.red,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(
                        alreadyOwned
                            ? '보유 중'
                            : (canAfford ? '구매하기' : '포인트 부족'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryTab extends StatelessWidget {
  const _InventoryTab({
    required this.profile,
    required this.isProcessing,
    required this.onEquipTitle,
  });

  final UserProfile profile;
  final bool isProcessing;
  final ValueChanged<String?> onEquipTitle;

  @override
  Widget build(BuildContext context) {
    final ownedTitleItems = profile.ownedTitles
        .map(ShopCatalog.findById)
        .whereType<ShopItem>()
        .toList();

    final nicknameItem = ShopCatalog.findById(ShopCatalog.nicknameTicketId)!;
    final boostItem = ShopCatalog.findById(ShopCatalog.caseBoostId)!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      children: [
        const Text(
          '보유 중인 소모품 티켓',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _TicketInventoryCard(
                item: nicknameItem,
                count: profile.nicknameTickets,
                usageHint: '프로필 → 계정 설정에서 사용',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TicketInventoryCard(
                item: boostItem,
                count: profile.boostTickets,
                usageHint: '내 사건 상세에서 사용',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(
              child: Text(
                '보유 중인 특별 칭호',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ),
            if (profile.equippedTitleId != null)
              TextButton(
                onPressed: isProcessing ? null : () => onEquipTitle(null),
                child: const Text('칭호 해제'),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (ownedTitleItems.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: const Text(
              '아직 구매한 특별 칭호가 없습니다. 상점 탭에서 포인트로 구매해 장착해 보세요!',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          )
        else
          ...ownedTitleItems.map((item) {
            final equipped = profile.equippedTitleId == item.id;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: equipped ? item.accentColor : AppColors.line,
                  width: equipped ? 1.5 : 1,
                ),
              ),
              child: ListTile(
                leading: _ShopItemThumbnail(item: item, size: 46),
                title: Row(
                  children: [
                    UserTitleBadge(titleItem: item),
                  ],
                ),
                subtitle: Text(
                  equipped ? '현재 모든 화면에 장착 중' : '탭하여 프로필·랭킹·토론에 장착',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: equipped
                    ? OutlinedButton(
                        onPressed:
                            isProcessing ? null : () => onEquipTitle(null),
                        child: const Text('해제'),
                      )
                    : FilledButton(
                        onPressed:
                            isProcessing ? null : () => onEquipTitle(item.id),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.red,
                        ),
                        child: const Text('장착'),
                      ),
              ),
            );
          }),
        const SizedBox(height: 20),
        const Text(
          '레벨 자동 진화 테두리 도감',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        const Text(
          '레벨이 오르면 프로필·랭킹·토론의 테두리가 자동으로 진화합니다.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _FramePreviewCell(
                label: 'Lv.1~4\n실버',
                level: 1,
                photoUrl: profile.photoUrl,
                unlocked: profile.level >= 1,
              ),
              _FramePreviewCell(
                label: 'Lv.5~9\n사파이어',
                level: 5,
                photoUrl: profile.photoUrl,
                unlocked: profile.level >= 5,
              ),
              _FramePreviewCell(
                label: 'Lv.10~19\n루비',
                level: 10,
                photoUrl: profile.photoUrl,
                unlocked: profile.level >= 10,
              ),
              _FramePreviewCell(
                label: 'Lv.20+\n챌린저',
                level: 20,
                photoUrl: profile.photoUrl,
                unlocked: profile.level >= 20,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TicketInventoryCard extends StatelessWidget {
  const _TicketInventoryCard({
    required this.item,
    required this.count,
    required this.usageHint,
  });

  final ShopItem item;
  final int count;
  final String usageHint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          _ShopItemThumbnail(item: item, size: 54),
          const SizedBox(height: 8),
          Text(
            item.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            '$count장 보유',
            style: TextStyle(
              color: count > 0 ? AppColors.red : AppColors.muted,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            usageHint,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _FramePreviewCell extends StatelessWidget {
  const _FramePreviewCell({
    required this.label,
    required this.level,
    required this.photoUrl,
    required this.unlocked,
  });

  final String label;
  final int level;
  final String? photoUrl;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Opacity(
          opacity: unlocked ? 1.0 : 0.45,
          child: LevelUserAvatar(
            level: level,
            photoUrl: photoUrl,
            radius: 22,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: unlocked ? AppColors.ink : AppColors.muted,
          ),
        ),
      ],
    );
  }
}

class _ShopItemThumbnail extends StatelessWidget {
  const _ShopItemThumbnail({required this.item, required this.size});
  final ShopItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: size,
        height: size,
        color: item.accentColor.withValues(alpha: 0.12),
        child: Image.asset(
          item.assetPath,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(
            item.fallbackIcon,
            size: size * 0.52,
            color: item.accentColor,
          ),
        ),
      ),
    );
  }
}