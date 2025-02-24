import Flutter
import UIKit
import Firebase
import FirebaseCore
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialize Flutter first
    GeneratedPluginRegistrant.register(with: self)
    
    // Then initialize Firebase
    if FirebaseApp.app() == nil {
        let filePath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist")
        if let filePath = filePath {
            print("[Firebase] Found GoogleService-Info.plist at: \(filePath)")
            do {
                FirebaseApp.configure()
                print("[Firebase] Successfully configured")
                
                // Set messaging delegate
                Messaging.messaging().delegate = self
                
                // Request permission for push notifications
                if #available(iOS 10.0, *) {
                    UNUserNotificationCenter.current().delegate = self
                    let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
                    UNUserNotificationCenter.current().requestAuthorization(
                        options: authOptions,
                        completionHandler: { granted, error in
                            print("[Firebase] Notification authorization - granted: \(granted), error: \(String(describing: error))")
                        }
                    )
                }
                application.registerForRemoteNotifications()
                
            } catch let error {
                print("[Firebase] Configuration error: \(error.localizedDescription)")
                return false
            }
        } else {
            print("[Firebase] Error: GoogleService-Info.plist not found")
            return false
        }
    } else {
        print("[Firebase] Already configured")
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Handle remote notification registration
  override func application(_ application: UIApplication,
                          didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    print("[Firebase] Successfully registered for notifications with token")
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
  
  // Failed to register for remote notifications
  override func application(_ application: UIApplication,
                          didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("[Firebase] Failed to register for remote notifications: \(error.localizedDescription)")
  }
  
  // MessagingDelegate method
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("[Firebase] FCM token received: \(String(describing: fcmToken))")
    let dataDict: [String: String] = ["token": fcmToken ?? ""]
    NotificationCenter.default.post(
      name: Notification.Name("FCMToken"),
      object: nil,
      userInfo: dataDict
    )
  }
}
