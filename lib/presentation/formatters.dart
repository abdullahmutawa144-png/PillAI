const _months = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const _weekdays = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String formatTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${value.hour < 12 ? 'AM' : 'PM'}';
}

String formatCompactTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute == 0
      ? ''
      : ':${value.minute.toString().padLeft(2, '0')}';
  return '$hour$minute ${value.hour < 12 ? 'AM' : 'PM'}';
}

String formatDay(DateTime value) => _weekdays[value.weekday - 1];

String formatDate(DateTime value) => '${_months[value.month - 1]} ${value.day}';
