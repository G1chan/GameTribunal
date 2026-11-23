class GameCase {
  GameCase({required this.id, required this.game, required this.title, required this.status, required this.leftRate, required this.rightRate, required this.comments, this.live = false, this.description = ''});
  final String id, game, title, status, description;
  int leftRate, rightRate, comments;
  final bool live;
}
