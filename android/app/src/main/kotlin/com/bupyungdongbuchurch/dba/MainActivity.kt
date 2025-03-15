package com.bupyungdongbuchurch.dba

import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        try {
            GeneratedPluginRegistrant.registerWith(flutterEngine)
            Log.d("FlutterApp", "플러그인 등록 성공")
        } catch (e: Exception) {
            Log.e("FlutterApp", "플러그인 등록 실패", e)
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        try {
            super.onCreate(savedInstanceState)
            Log.d("FlutterApp", "MainActivity onCreate 성공")
        } catch (e: Exception) {
            Log.e("FlutterApp", "MainActivity onCreate 실패", e)
        }
    }
} 