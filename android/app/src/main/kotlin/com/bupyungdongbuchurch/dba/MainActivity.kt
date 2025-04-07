package com.bupyungdongbuchurch.dba

import android.app.ActivityManager
import android.app.PictureInPictureParams
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Rect
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.util.Rational
import android.view.View
import android.view.WindowManager
import androidx.annotation.NonNull
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.bupyungdongbuchurch.dba/pip"
    private var isPipModePending = false
    private var isInPipMode = false
    private var isVideoPlaying = false
    private var pipParamsBuilder: PictureInPictureParams.Builder? = null
    private var hasPipPermission = false
    
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        try {
            GeneratedPluginRegistrant.registerWith(flutterEngine)
            Log.d("FlutterApp", "플러그인 등록 성공")
            
            // PIP 패러미터 미리 생성 (Android 8 이상에서만)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                try {
                    pipParamsBuilder = PictureInPictureParams.Builder()
                    
                    // 화면 비율 설정
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        pipParamsBuilder?.setAspectRatio(Rational(16, 9))
                                ?.setSeamlessResizeEnabled(true)
                                ?.setAutoEnterEnabled(true)
                    } else {
                        pipParamsBuilder?.setAspectRatio(Rational(16, 9))
                    }
                    
                    // PIP 지원 여부 확인 (필요한 경우)
                    hasPipPermission = packageManager.hasSystemFeature(android.content.pm.PackageManager.FEATURE_PICTURE_IN_PICTURE)
                    Log.d("FlutterApp", "PIP 권한 확인: $hasPipPermission")
                } catch (e: Exception) {
                    Log.e("FlutterApp", "PIP 파라미터 생성 실패", e)
                }
            }
            
            // PIP 기능을 위한 Method Channel 설정
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
                when (call.method) {
                    "enterPipMode" -> {
                        val enterPipSuccess = enterPipMode()
                        result.success(enterPipSuccess)
                    }
                    "preparePipMode" -> {
                        // YouTube 화면이 활성화됨을 표시
                        isPipModePending = true
                        isVideoPlaying = true
                        Log.d("FlutterApp", "PIP 모드 준비됨 (preparePipMode 호출): isPipModePending=$isPipModePending, isVideoPlaying=$isVideoPlaying")
                        result.success(true)
                    }
                    "cancelPipMode" -> {
                        // YouTube 화면이 비활성화됨을 표시
                        isPipModePending = false
                        isVideoPlaying = false
                        Log.d("FlutterApp", "PIP 모드 취소됨 (cancelPipMode 호출): isPipModePending=$isPipModePending, isVideoPlaying=$isVideoPlaying")
                        result.success(true)
                    }
                    "isPipSupported" -> {
                        // PIP 지원 여부 확인
                        val isSupported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && hasPipPermission
                        result.success(isSupported)
                    }
                    else -> result.notImplemented()
                }
            }
        } catch (e: Exception) {
            Log.e("FlutterApp", "플러그인 등록 실패", e)
        }
    }
    
    // PIP 모드 상태 변경 감지
    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        
        isInPipMode = isInPictureInPictureMode
        Log.d("FlutterApp", "PIP 모드 상태 변경: $isInPictureInPictureMode")
        
        if (!isInPictureInPictureMode) {
            // PIP 모드 종료 시 처리 (필요한 경우)
            Log.d("FlutterApp", "PIP 모드가 종료되었습니다")
        } else {
            Log.d("FlutterApp", "PIP 모드가 시작되었습니다")
        }
    }
    
    // 추가: onStop 메서드 오버라이드 - 더 넓은 범위의 라이프사이클 이벤트를 캡처하기 위함
    override fun onStop() {
        super.onStop()
        
        Log.d("FlutterApp", "onStop 호출됨, PIP 모드 대기 상태: $isPipModePending, 현재 PIP 모드: $isInPipMode, 비디오 재생 중: $isVideoPlaying")
        
        // PIP 모드 대기 중이고 현재 PIP 모드가 아니면 PIP 모드 시도
        if (isPipModePending && !isInPipMode && isVideoPlaying) {
            Log.d("FlutterApp", "onStop에서 PIP 모드 시도")
            enterPipMode()
        }
    }
    
    // 추가: onPause 메서드 오버라이드 - 일부 기기에서는 이 시점에서 PIP 모드 전환을 해야 함
    override fun onPause() {
        super.onPause()
        
        Log.d("FlutterApp", "onPause 호출됨, PIP 모드 대기 상태: $isPipModePending, 현재 PIP 모드: $isInPipMode, 비디오 재생 중: $isVideoPlaying")
        
        // isPipModePending 플래그가 켜져 있고, 아직 PIP 모드가 아니면서 비디오가 재생 중이라면
        if (isPipModePending && !isInPipMode && isVideoPlaying) {
            Log.d("FlutterApp", "onPause에서 PIP 모드 시도")
            enterPipMode()
        }
    }
    
    // 사용자가 홈 버튼 등을 눌러 앱을 떠날 때 호출됨
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        
        Log.d("FlutterApp", "onUserLeaveHint 호출됨, PIP 모드 대기 상태: $isPipModePending, 현재 PIP 모드: $isInPipMode, 비디오 재생 중: $isVideoPlaying")
        
        // isPipModePending 플래그가 켜져 있고, 아직 PIP 모드가 아니면서 비디오가 재생 중이라면
        if (isPipModePending && !isInPipMode && isVideoPlaying) {
            Log.d("FlutterApp", "사용자가 앱을 떠남 - PIP 모드 자동 시작")
            
            // 즉시 시도
            enterPipMode()
            
            // 약간의 지연 후 한 번 더 시도 (일부 기기에서는 즉시 호출이 무시될 수 있음)
            Handler(Looper.getMainLooper()).postDelayed({
                if (isPipModePending && !isInPipMode && isVideoPlaying) {
                    Log.d("FlutterApp", "지연 후 PIP 모드 재시도")
                    enterPipMode()
                }
            }, 250)
        } else {
            Log.d("FlutterApp", "PIP 모드 조건 불충족 - PIP 모드 시작하지 않음")
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        try {
            super.onCreate(savedInstanceState)
            
            // Edge-to-Edge 디스플레이 지원 활성화
            WindowCompat.setDecorFitsSystemWindows(window, false)
            
            // System UI 컨트롤러
            val windowInsetsController = WindowInsetsControllerCompat(window, window.decorView)
            
            // 시스템 바 모양 설정
            windowInsetsController.isAppearanceLightStatusBars = !isDarkMode()
            windowInsetsController.isAppearanceLightNavigationBars = !isDarkMode()
            
            // 시스템 바 동작 설정
            windowInsetsController.systemBarsBehavior = 
                WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                
            // PIP 모드를 위한 설정
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                try {
                    // 액티비티 PIP 모드 지원 설정
                    setPictureInPictureParams(
                        PictureInPictureParams.Builder()
                            .setAspectRatio(Rational(16, 9))
                            .build()
                    )
                } catch (e: Exception) {
                    Log.e("FlutterApp", "PIP 파라미터 설정 실패", e)
                }
            }
            
            Log.d("FlutterApp", "MainActivity onCreate 성공")
        } catch (e: Exception) {
            Log.e("FlutterApp", "MainActivity onCreate 실패", e)
        }
    }
    
    // PIP 모드 진입 함수 (직접적인 방법으로 변경)
    private fun enterPipMode(): Boolean {
        Log.d("FlutterApp", "PIP 모드 진입 시도")
        
        if (isInPipMode) {
            Log.d("FlutterApp", "이미 PIP 모드 상태입니다")
            return true
        }
        
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            Log.e("FlutterApp", "PIP 기능은 Android 8.0 이상에서만 지원됩니다. 현재 버전: ${Build.VERSION.SDK_INT}")
            return false
        }
        
        try {
            Log.d("FlutterApp", "Android 버전 확인 (Android 8.0 이상)")
            
            // 최종 PIP 파라미터 빌더를 가져옴
            val finalBuilder = PictureInPictureParams.Builder()
            
            // 기본 비율과 원활한 크기 조정 설정
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                finalBuilder.setAspectRatio(Rational(16, 9))
                    .setSeamlessResizeEnabled(true)
                    .setAutoEnterEnabled(true)
            } else {
                finalBuilder.setAspectRatio(Rational(16, 9))
            }
            
            // 소스 경계 설정 (전체 화면 사용)
            val sourceRectHint = Rect(0, 0, window.decorView.width, window.decorView.height)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                finalBuilder.setSourceRectHint(sourceRectHint)
            }
            
            // PIP 모드 진입
            val params = finalBuilder.build()
            val result = enterPictureInPictureMode(params)
            Log.d("FlutterApp", "PIP 모드 진입 결과: $result")
            
            // PIP 권한 및 상태 확인
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val supportsMultiWindow = activityManager.isActivityStartAllowedOnDisplay(this, 0, Intent())
            Log.d("FlutterApp", "멀티윈도우 지원 여부: $supportsMultiWindow")
            Log.d("FlutterApp", "PIP 지원 여부: ${packageManager.hasSystemFeature(android.content.pm.PackageManager.FEATURE_PICTURE_IN_PICTURE)}")
            
            // 진입에 실패한 경우 한 번 더 시도 (약간의 지연 후)
            if (!result) {
                Log.d("FlutterApp", "PIP 모드 진입 실패, 재시도 중...")
                
                Handler(Looper.getMainLooper()).postDelayed({
                    try {
                        val retryBuilder = PictureInPictureParams.Builder()
                            .setAspectRatio(Rational(16, 9))
                        
                        val retryResult = enterPictureInPictureMode(retryBuilder.build())
                        Log.d("FlutterApp", "PIP 모드 재시도 결과: $retryResult")
                    } catch (e: Exception) {
                        Log.e("FlutterApp", "PIP 모드 재시도 중 오류: ${e.message}", e)
                    }
                }, 250)
            }
            
            return result
        } catch (e: Exception) {
            Log.e("FlutterApp", "PIP 모드 진입 실패: ${e.message}", e)
            return false
        }
    }
    
    // 다크 모드 확인 함수
    private fun isDarkMode(): Boolean {
        return resources.configuration.uiMode and 
            android.content.res.Configuration.UI_MODE_NIGHT_MASK == 
            android.content.res.Configuration.UI_MODE_NIGHT_YES
    }
} 