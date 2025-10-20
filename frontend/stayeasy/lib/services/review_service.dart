import '../config/api_constants.dart';
import '../models/review.dart';
import 'api_service.dart';
import '../utils/api_data_parser.dart';

class ReviewService {
  final _api = ApiService();

  Future<List<Review>> getByHotel(int hotelId) async {
    final raw = await _api.get(ApiConstants.reviewsGetByHotel(hotelId));
    return ApiDataParser.list(raw).map((e) => Review.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<Review> create({
    required int hotelId,
    required int userId,
    required int rating,
    required String comment,
  }) async {
    // Backend mới sẽ nhận POST /api/reviews {hotelId, userId, rating, comment}
    final raw = await _api.post(ApiConstants.reviews, {
      'hotelId': hotelId,
      'userId': userId,
      'rating': rating,
      'comment': comment,
    });
    final m = ApiDataParser.map(raw);
    return Review.fromJson(Map<String, dynamic>.from(m['data'] ?? m));
  }
}
