import 'package:squawker/database/repository.dart';
import 'package:sqflite/sqflite.dart';

class TweetHistoryService {
  static Future<void> markViewed(String tweetId, {String? userId, String? screenName}) async {
    try {
      final db = await Repository.writable();
      await db.insert(
        tableTweetHistory,
        {
          'tweet_id': tweetId,
          'viewed_at': DateTime.now().toIso8601String(),
          'opened': 0,
          'user_id': userId,
          'screen_name': screenName,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      // Ignore errors
    }
  }

  static Future<void> markOpened(String tweetId, {String? userId, String? screenName}) async {
    try {
      final db = await Repository.writable();
      await db.insert(
        tableTweetHistory,
        {
          'tweet_id': tweetId,
          'viewed_at': DateTime.now().toIso8601String(),
          'opened': 1,
          'user_id': userId,
          'screen_name': screenName,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      // Ignore errors
    }
  }

  static Future<bool> isViewed(String tweetId) async {
    try {
      final db = await Repository.writable();
      final result = await db.query(
        tableTweetHistory,
        where: 'tweet_id = ? AND opened = 0',
        whereArgs: [tweetId],
      );
      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> isOpened(String tweetId) async {
    try {
      final db = await Repository.writable();
      final result = await db.query(
        tableTweetHistory,
        where: 'tweet_id = ? AND opened = 1',
        whereArgs: [tweetId],
      );
      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getViewedHistory({int limit = 100}) async {
    try {
      final db = await Repository.writable();
      return await db.query(
        tableTweetHistory,
        where: 'opened = 0',
        orderBy: 'viewed_at DESC',
        limit: limit,
      );
    } catch (e) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getOpenedHistory({int limit = 100}) async {
    try {
      final db = await Repository.writable();
      return await db.query(
        tableTweetHistory,
        where: 'opened = 1',
        orderBy: 'viewed_at DESC',
        limit: limit,
      );
    } catch (e) {
      return [];
    }
  }

  static Future<void> clearHistory() async {
    try {
      final db = await Repository.writable();
      await db.delete(tableTweetHistory);
    } catch (e) {
      // Ignore errors
    }
  }
}
