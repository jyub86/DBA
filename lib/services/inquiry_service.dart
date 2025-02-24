import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/inquiry_model.dart';
import 'package:dba/services/logger_service.dart';

class InquiryService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Inquiry>> getInquiries(String userId) async {
    try {
      final response = await _client
          .from('inquiries')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return response.map<Inquiry>((json) => Inquiry.fromMap(json)).toList();
    } catch (e, stackTrace) {
      LoggerService.error('문의 조회 중 오류 발생', e, stackTrace);
      rethrow;
    }
  }

  Future<Inquiry> createInquiry({
    required String title,
    required String content,
    required String userId,
  }) async {
    try {
      final data = {
        'title': title,
        'content': content,
        'user_id': userId,
        'is_resolved': false,
        'created_at': DateTime.now().toIso8601String(),
      };

      final response =
          await _client.from('inquiries').insert(data).select().single();
      return Inquiry.fromMap(response);
    } catch (e, stackTrace) {
      LoggerService.error('문의 생성 중 오류 발생', e, stackTrace);
      rethrow;
    }
  }

  Future<void> updateInquiry(String id, Map<String, dynamic> data) async {
    await _client.from('inquiries').update(data).eq('id', id);
  }

  Future<void> deleteInquiry(String id) async {
    await _client.from('inquiries').delete().eq('id', id);
  }

  Future<List<Inquiry>> getAdminInquiries() async {
    ('관리자 문의 목록 조회');
    try {
      final response = await _client
          .from('inquiries')
          .select()
          .order('created_at', ascending: false);
      return response.map<Inquiry>((json) => Inquiry.fromMap(json)).toList();
    } catch (e, stackTrace) {
      LoggerService.error('관리자 문의 조회 중 오류 발생', e, stackTrace);
      rethrow;
    }
  }

  Future<void> answerInquiry({
    required String id,
    required String answer,
    required String answeredBy,
  }) async {
    try {
      final data = {
        'answer': answer,
        'answered_by': answeredBy,
        'answered_at': DateTime.now().toIso8601String(),
        'is_resolved': true,
      };

      await _client.from('inquiries').update(data).eq('id', id);
    } catch (e, stackTrace) {
      LoggerService.error('문의 답변 중 오류 발생', e, stackTrace);
      rethrow;
    }
  }
}
