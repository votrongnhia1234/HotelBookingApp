class Review {
  final int id;
  final int hotelId;
  final int userId;
  final int rating;
  final String comment;
  final String createdAt;

  Review({
    required this.id,
    required this.hotelId,
    required this.userId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> j) => Review(
    id: j['id'] is int ? j['id'] : int.tryParse('${j['id']}') ?? 0,
    hotelId: j['hotelId'] is int ? j['hotelId'] : int.tryParse('${j['hotelId']}') ?? 0,
    userId: j['userId'] is int ? j['userId'] : int.tryParse('${j['userId']}') ?? 0,
    rating: j['rating'] is int ? j['rating'] : int.tryParse('${j['rating']}') ?? 0,
    comment: j['comment']?.toString() ?? '',
    createdAt: j['createdAt']?.toString() ?? j['created_at']?.toString() ?? '',
  );
}
