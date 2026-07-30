String motionItemId(Map<String, dynamic> item) =>
    item['id']?.toString().trim() ?? '';

String motionItemLabel(Map<String, dynamic> item) {
  final displayName = item['display_name']?.toString().trim() ?? '';
  return displayName.isNotEmpty ? displayName : motionItemId(item);
}

String? motionItemDescription(Map<String, dynamic> item) {
  final description = item['description']?.toString().trim() ?? '';
  return description.isEmpty ? null : description;
}
