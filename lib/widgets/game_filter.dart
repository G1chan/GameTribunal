import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GameFilter extends StatelessWidget {
  const GameFilter({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const games = ['전체', '관심 종목', '리그 오브 레전드', '발로란트', '오버워치 2'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: games.map((game) {
          final selected = game == value;
          return Padding(
            padding: const EdgeInsets.only(right: 7),
            child: ChoiceChip(
              label: Text(game),
              selected: selected,
              onSelected: (_) => onChanged(game),
              labelStyle: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.muted,
              ),
              selectedColor: AppColors.red,
              backgroundColor: AppColors.surface,
              side: BorderSide(color: selected ? AppColors.red : AppColors.line),
            ),
          );
        }).toList(),
      ),
    );
  }
}