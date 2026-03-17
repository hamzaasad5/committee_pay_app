String generateCommitteeCode() {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  final random = List.generate(5, (index) {
    final i = DateTime.now().millisecondsSinceEpoch + index;
    return chars[i % chars.length];
  }).join();
  return "CT-$random";
}