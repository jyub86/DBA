package com.bupyungdongbuchurch.dba

import android.app.Application
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

class MyApplication : Application() {
    lateinit var flutterEngine: FlutterEngine

    override fun onCreate() {
        super.onCreate()
        
        try {
            Log.d("FlutterApp", "Application 초기화 성공")
            
            // 사전 엔진 초기화 비활성화 (문제 해결을 위해)
            /* 
            // Flutter 엔진 초기화
            flutterEngine = FlutterEngine(this)
            
            // 엔진 초기화 전에 메모리 상태 확인
            val runtime = Runtime.getRuntime()
            val usedMemoryMb = (runtime.totalMemory() - runtime.freeMemory()) / 1048576L
            val maxHeapSizeMb = runtime.maxMemory() / 1048576L
            val availableHeapSizeMb = maxHeapSizeMb - usedMemoryMb
            
            Log.d("FlutterApp", "Memory - Used: $usedMemoryMb MB, Max: $maxHeapSizeMb MB, Available: $availableHeapSizeMb MB")
            
            // Dart 엔트리포인트 실행
            flutterEngine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
            
            // 엔진을 캐시에 저장
            FlutterEngineCache.getInstance().put("my_engine_id", flutterEngine)
            
            Log.d("FlutterApp", "Flutter 엔진 초기화 성공")
            */
        } catch (e: Exception) {
            Log.e("FlutterApp", "Flutter 엔진 초기화 실패", e)
            // 예외 발생 시 복구 시도 비활성화
            /*
            try {
                flutterEngine = FlutterEngine(this)
                FlutterEngineCache.getInstance().put("my_engine_id", flutterEngine)
                Log.d("FlutterApp", "Flutter 엔진 복구 성공")
            } catch (e2: Exception) {
                Log.e("FlutterApp", "Flutter 엔진 복구 실패", e2)
            }
            */
        }
    }
} 