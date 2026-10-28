import Flutter
import StoreKit
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = self.registrar(forPlugin: "OtoSinyalNative") {
      OtoSinyalNative.register(messenger: registrar.messenger())
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

/// Uygulamaya özel küçük yerel köprü: App Store puan penceresi ve
/// bakım hatırlatıcıları için yerel bildirimler.
/// Dart tarafı: lib/services/native_bridge.dart
enum OtoSinyalNative {
  static let channelName = "otosinyal/native"

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "requestReview":
        requestReview()
        result(nil)
      case "notificationStatus":
        UNUserNotificationCenter.current().getNotificationSettings { settings in
          let value: String
          switch settings.authorizationStatus {
          case .authorized, .provisional: value = "authorized"
          case .denied: value = "denied"
          default: value = "notDetermined"
          }
          DispatchQueue.main.async { result(value) }
        }
      case "requestNotificationPermission":
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
          DispatchQueue.main.async { result(granted) }
        }
      case "scheduleNotification":
        guard
          let args = call.arguments as? [String: Any],
          let id = args["id"] as? String,
          let title = args["title"] as? String,
          let body = args["body"] as? String,
          let epochMs = (args["epochMs"] as? NSNumber)?.doubleValue
        else {
          result(FlutterError(code: "bad_args", message: "id, title, body, epochMs required", details: nil))
          return
        }
        let fireDate = Date(timeIntervalSince1970: epochMs / 1000.0)
        guard fireDate.timeIntervalSinceNow > 1 else {
          result(false)
          return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
          DispatchQueue.main.async { result(error == nil) }
        }
      case "cancelNotifications":
        let ids = (call.arguments as? [String: Any])?["ids"] as? [String] ?? []
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func requestReview() {
    if #available(iOS 14.0, *) {
      let scene = UIApplication.shared.connectedScenes
        .first { $0.activationState == .foregroundActive } as? UIWindowScene
      if let scene = scene {
        SKStoreReviewController.requestReview(in: scene)
      }
    } else {
      SKStoreReviewController.requestReview()
    }
  }
}
