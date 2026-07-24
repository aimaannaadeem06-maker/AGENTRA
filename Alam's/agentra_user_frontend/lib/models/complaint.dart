class Complaint {
  final String id;
  final String userId;
  final String? bookingId;
  final String? agentId;
  final String? agentName;
  final String subject;
  final String description;
  final String status; // OPEN | IN_PROGRESS | RESOLVED
  final bool forwardedToAgent;
  final String? adminResponse;
  final String? agentResponse;
  final DateTime createdAt;

  Complaint({
    required this.id,
    required this.userId,
    this.bookingId,
    this.agentId,
    this.agentName,
    required this.subject,
    required this.description,
    required this.status,
    this.forwardedToAgent = false,
    this.adminResponse,
    this.agentResponse,
    required this.createdAt,
  });

  factory Complaint.fromJson(Map<String, dynamic> json) {
    final agentRaw = json['agentId'];
    return Complaint(
      id:               json['_id'] ?? json['id'] ?? '',
      userId:           json['userId'] is Map
                          ? (json['userId']['_id'] ?? '')
                          : (json['userId'] ?? ''),
      bookingId:        json['bookingId'] is Map
                          ? (json['bookingId']['_id'] ?? '')
                          : json['bookingId'],
      agentId:          agentRaw is Map ? (agentRaw['_id'] ?? '') : agentRaw,
      agentName:        agentRaw is Map
                          ? (agentRaw['businessName'] ?? agentRaw['fullName'])
                          : null,
      subject:          json['subject'] ?? '',
      description:      json['description'] ?? '',
      status:           json['status'] ?? 'OPEN',
      forwardedToAgent: json['forwardedToAgent'] ?? false,
      adminResponse:    json['adminResponse'] ?? json['ownerResponse'],
      agentResponse:    json['agentResponse'],
      createdAt:        json['createdAt'] != null
                          ? DateTime.parse(json['createdAt'])
                          : DateTime.now(),
    );
  }

  /// Human-readable status label
  String get statusLabel {
    switch (status.toUpperCase()) {
      case 'IN_PROGRESS': return 'In Progress';
      case 'RESOLVED':    return 'Resolved';
      default:            return 'Open';
    }
  }
}
