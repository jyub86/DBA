import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/category_model.dart';

class CategoryService {
  static final CategoryService instance = CategoryService._();
  final Map<String, int> _categoryCache = {};
  final _supabase = Supabase.instance.client;

  CategoryService._();

  Future<int?> getCategoryId(String categoryName) async {
    // 캐시된 카테고리 ID가 있으면 반환
    if (_categoryCache.containsKey(categoryName)) {
      return _categoryCache[categoryName];
    }

    try {
      final response = await _supabase
          .from('categories')
          .select()
          .eq('name', categoryName)
          .single();

      final category = CategoryModel.fromJson(response);
      // 캐시에 저장
      _categoryCache[categoryName] = category.id;
      return category.id;
    } catch (e) {
      return null;
    }
  }

  Future<List<CategoryModel>> getCategories({bool activeOnly = true}) async {
    try {
      final query = _supabase.from('categories').select();

      if (activeOnly) {
        query.eq('active', true);
      }

      final response = await query.order('order', ascending: true);

      return List<CategoryModel>.from(
        response.map((data) => CategoryModel.fromJson(data)),
      );
    } catch (e) {
      return [];
    }
  }
}
