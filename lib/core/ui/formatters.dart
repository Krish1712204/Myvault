/// Display formatting shared across screens.
library;

const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Just now", "5m ago", "3h ago", "2d ago", "3w ago", "4mo ago", "2y ago".
String relativeTime(int millis, DateTime now) {
  final diff = now.difference(DateTime.fromMillisecondsSinceEpoch(millis));
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
  return '${(diff.inDays / 365).floor()}y ago';
}

/// "19 Nov 2026, 4:05 PM".
String formatDateTime(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.hour >= 12 ? 'PM' : 'AM';
  return '${time.day} ${_months[time.month - 1]} ${time.year}, $hour:$minute $period';
}
