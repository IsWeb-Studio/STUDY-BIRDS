bool isCurrentLibraryDocument(Map document) =>
    document['supersededBy'] == null &&
    document['isLatest'] != false &&
    document['translationOf'] == null &&
    document['archivedAt'] == null;

bool isUsableLibraryDocument(Map document) {
  if (!isCurrentLibraryDocument(document)) return false;
  final expiry = DateTime.tryParse('${document['expiresAt'] ?? ''}');
  return (expiry == null || expiry.isAfter(DateTime.now())) &&
      (document['uploadStatus'] == null ||
          document['uploadStatus'] == 'uploaded') &&
      document['status'] != 'rejected' &&
      !['missing', 'rejected', 'needs-revision', 'needs-translation', 'expired']
          .contains(document['detailedStatus']);
}
