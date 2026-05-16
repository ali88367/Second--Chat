import UIKit
import Flutter
import Firebase
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FirebaseApp.configure()

        GeneratedPluginRegistrant.register(with: self)
        Messaging.messaging().delegate = self

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // Handle APNs registration
    override func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("APNs Device Token: \(token)")

        Messaging.messaging().apnsToken = deviceToken
        Messaging.messaging().setAPNSToken(deviceToken, type: .prod)
    }
    
    // Handle Universal Links - This prevents Safari from opening
    override func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        // Check if this is a universal link
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = userActivity.webpageURL {
            print("🔗 Universal link received in AppDelegate: \(url.absoluteString)")
            print("🔗 URL host: \(url.host ?? "nil")")
            print("🔗 App state: \(application.applicationState.rawValue)")
            
            // Check if it's our domain - CRITICAL: Handle synchronously but return true
            if let host = url.host, host == "app.frenzone.live" {
                print("✅ Our domain detected (app.frenzone.live)")
                print("✅ Processing universal link - preventing Safari")
                
                // Call super synchronously to let Flutter process the link immediately
                // This ensures Flutter receives the link for navigation
                let flutterHandled = super.application(application, continue: userActivity, restorationHandler: restorationHandler)
                print("🔗 Flutter handled result: \(flutterHandled)")
                
                // CRITICAL: Always return true for our domain to prevent Safari
                // Even if Flutter's handling returns false, we've claimed the link
                // This prevents iOS from falling back to Safari
                return true
            } else {
                print("⚠️ Not our domain: \(url.host ?? "nil") - using default handling")
            }
            
            // For other domains, use default handling
            return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
        }
        
        // For other activity types, use default handling
        return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }
    
    // Handle URL schemes (backup method)
    override func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        print("🔗 URL scheme received in AppDelegate: \(url.absoluteString)")
        
        // Let Flutter handle it
        let handled = super.application(app, open: url, options: options)
        
        if handled {
            print("✅ URL scheme handled by Flutter")
        }
        
        // Return true to prevent other apps from handling it
        return handled
    }
}