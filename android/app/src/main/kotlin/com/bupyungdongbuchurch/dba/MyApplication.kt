package com.bupyungdongbuchurch.dba

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

class MyApplication : Application() {
    lateinit var flutterEngine: FlutterEngine

    override fun onCreate() {
        super.onCreate()
        
        // Flutter 엔진 초기화
        flutterEngine = FlutterEngine(this)
        flutterEngine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        
        // 엔진을 캐시에 저장
        FlutterEngineCache.getInstance().put("my_engine_id", flutterEngine)
    }
} 