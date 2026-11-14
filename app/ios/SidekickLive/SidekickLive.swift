// The SidekickLive widget extension: a transfer's Live Activity on the Lock
// Screen and in the Dynamic Island (TransferActivityAttributes, shared with
// the app; the app starts, updates and ends it), and the home-screen widgets
// (4.0: the last file received, and up to three devices with Send and Ping),
// which draw what the app writes to the App Group (AppDelegate updateWidgets).

import ActivityKit
import SwiftUI
import WidgetKit

@main
struct SidekickLiveBundle: WidgetBundle {
  var body: some Widget {
    TransferLiveActivity()
    SidekickLastFileWidget()
    SidekickDevicesWidget()
  }
}

/// Sidekick's purple, and the colors that go with it.
private let accent = Color(red: 0.56, green: 0.40, blue: 0.98)
private let accent2 = Color(red: 0.93, green: 0.42, blue: 0.67)
private let failure = Color(red: 1.0, green: 0.42, blue: 0.42)

private typealias Context = ActivityViewContext<TransferActivityAttributes>

private func fraction(_ s: TransferActivityAttributes.ContentState) -> Double {
  if s.finished && !s.failed { return 1 }
  guard s.total > 0 else { return 0 }
  return min(max(Double(s.done) / Double(s.total), 0), 1)
}

private func bytes(_ n: Int64) -> String {
  ByteCountFormatter.string(fromByteCount: n, countStyle: .file)
}

private func symbol(_ c: Context) -> String {
  if c.state.failed { return "xmark" }
  if c.state.finished { return "checkmark" }
  return c.attributes.incoming ? "arrow.down" : "arrow.up"
}

private func tint(_ c: Context) -> Color { c.state.failed ? failure : accent }

/// The arrow (or check) in a gradient circle, like the app's badge.
private struct Badge: View {
  let context: Context
  var size: CGFloat = 44

  var body: some View {
    ZStack {
      Circle()
        .fill(
          context.state.failed
            ? AnyShapeStyle(failure)
            : AnyShapeStyle(LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
      Image(systemName: symbol(context))
        .font(.system(size: size * 0.42, weight: .bold))
        .foregroundStyle(.white)
    }
    .frame(width: size, height: size)
  }
}

/// "Receiving from Mac · 12 MB of 44 MB"
private func detail(_ c: Context) -> String {
  let who = c.attributes.incoming ? "from \(c.attributes.device)" : "to \(c.attributes.device)"
  if c.state.finished { return "\(c.state.status) \(who)" }
  let amount = c.state.total > 0 ? " · \(bytes(c.state.done)) of \(bytes(c.state.total))" : ""
  return "\(c.state.status) \(who)\(amount)"
}

private func percent(_ c: Context) -> String {
  if c.state.failed { return "" }
  return "\(Int((fraction(c.state) * 100).rounded()))%"
}

struct TransferLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: TransferActivityAttributes.self) { context in
      // The Lock Screen, and the banner on iPhones without a Dynamic Island.
      VStack(alignment: .leading, spacing: 10) {
        HStack(spacing: 12) {
          Badge(context: context)
          VStack(alignment: .leading, spacing: 2) {
            Text(context.attributes.title)
              .font(.headline)
              .lineLimit(1)
            Text(detail(context))
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
          Spacer(minLength: 8)
          Text(percent(context))
            .font(.title3.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(tint(context))
        }
        ProgressView(value: fraction(context.state))
          .tint(tint(context))
      }
      .padding(16)
      .activitySystemActionForegroundColor(accent)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Badge(context: context, size: 38)
            .padding(.leading, 4)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text(percent(context))
            .font(.title3.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(tint(context))
            .padding(.trailing, 4)
        }
        DynamicIslandExpandedRegion(.center) {
          Text(context.attributes.title)
            .font(.headline)
            .lineLimit(1)
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: fraction(context.state))
              .tint(tint(context))
            Text(detail(context))
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
          .padding(.horizontal, 4)
        }
      } compactLeading: {
        Image(systemName: symbol(context))
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(tint(context))
      } compactTrailing: {
        ProgressView(value: fraction(context.state))
          .progressViewStyle(.circular)
          .tint(tint(context))
          .frame(width: 18, height: 18)
      } minimal: {
        ProgressView(value: fraction(context.state))
          .progressViewStyle(.circular)
          .tint(tint(context))
      }
      .keylineTint(accent)
    }
  }
}


// MARK: - Home-screen widgets (4.0)

private let widgetGroup = "group.dev.sidekick.sidekick"
private let wPanel = Color(red: 0.11, green: 0.11, blue: 0.11)
private let wRaised = Color(red: 0.18, green: 0.18, blue: 0.18)
private let wText = Color(red: 0.95, green: 0.95, blue: 0.95)
private let wMuted = Color(red: 0.63, green: 0.63, blue: 0.65)
private let wOk = Color(red: 0.27, green: 0.82, blue: 0.49)
private let wWhite = Color(red: 0.94, green: 0.94, blue: 0.94)
private let wOnWhite = Color(red: 0.08, green: 0.08, blue: 0.08)

struct WidgetDevice: Decodable, Identifiable {
  let id: String
  let name: String
  let kind: String
  let online: Bool
}

struct WidgetLast: Decodable {
  let name: String
  let from: String?
  let at: Double
}

struct WidgetData: Decodable {
  var last: WidgetLast?
  var devices: [WidgetDevice]

  static let empty = WidgetData(last: nil, devices: [])
  static let sample = WidgetData(
    last: WidgetLast(name: "Beach day.jpg", from: "MacBook Pro", at: Date().timeIntervalSince1970 * 1000 - 600_000),
    devices: [
      WidgetDevice(id: "a", name: "MacBook Pro", kind: "laptop", online: true),
      WidgetDevice(id: "b", name: "Studio PC", kind: "desktop", online: true),
      WidgetDevice(id: "c", name: "iPad mini", kind: "phone", online: false),
    ]
  )

  static func load() -> WidgetData {
    guard let raw = UserDefaults(suiteName: widgetGroup)?.string(forKey: "widget"),
      let data = raw.data(using: .utf8),
      let decoded = try? JSONDecoder().decode(WidgetData.self, from: data)
    else { return .empty }
    return decoded
  }
}

struct SidekickEntry: TimelineEntry {
  let date: Date
  let data: WidgetData
}

struct SidekickProvider: TimelineProvider {
  func placeholder(in context: TimelineProviderContext) -> SidekickEntry {
    SidekickEntry(date: Date(), data: .sample)
  }

  func getSnapshot(in context: TimelineProviderContext, completion: @escaping (SidekickEntry) -> Void) {
    completion(SidekickEntry(date: Date(), data: context.isPreview ? .sample : .load()))
  }

  func getTimeline(in context: TimelineProviderContext, completion: @escaping (Timeline<SidekickEntry>) -> Void) {
    // The app reloads them when something changes; a refresh now and then
    // keeps "10 min ago" honest.
    let entry = SidekickEntry(date: Date(), data: .load())
    completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30 * 60))))
  }
}

private extension View {
  @ViewBuilder func sidekickBackground() -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      containerBackground(wPanel, for: .widget)
    } else {
      padding().background(wPanel)
    }
  }
}

private func link(_ action: String, _ id: String? = nil) -> URL {
  var parts = URLComponents()
  parts.scheme = "sidekick"
  parts.host = action
  if let id { parts.queryItems = [URLQueryItem(name: "id", value: id)] }
  return parts.url ?? URL(string: "sidekick://open")!
}

/// Small: the last file received, or "Ready to receive".
struct SidekickLastFileWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "SidekickLastFile", provider: SidekickProvider()) { entry in
      LastFileView(data: entry.data)
    }
    .configurationDisplayName("Last file")
    .description("The last file you received, or that Sidekick is ready.")
    .supportedFamilies([.systemSmall])
  }
}

struct LastFileView: View {
  let data: WidgetData

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("sk").font(.system(size: 17, weight: .heavy)).foregroundStyle(wText)
      Spacer(minLength: 0)
      if let last = data.last {
        Text("Received").font(.system(size: 12)).foregroundStyle(wMuted)
        Text(last.name)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(wText)
          .lineLimit(2)
        Text(Date(timeIntervalSince1970: last.at / 1000), style: .relative)
          .font(.system(size: 12))
          .foregroundStyle(wMuted)
          .lineLimit(1)
      } else {
        Circle().fill(wOk).frame(width: 8, height: 8)
        Text("Ready to receive")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(wText)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .sidekickBackground()
    .widgetURL(link("open"))
  }
}

/// Medium: up to three devices, each with Send and Ping.
struct SidekickDevicesWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "SidekickDevices", provider: SidekickProvider()) { entry in
      DevicesView(data: entry.data)
    }
    .configurationDisplayName("Devices")
    .description("Your devices, with Send and Ping.")
    .supportedFamilies([.systemMedium])
  }
}

struct DevicesView: View {
  let data: WidgetData

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Sidekick").font(.system(size: 14, weight: .bold)).foregroundStyle(wText)
      if data.devices.isEmpty {
        Spacer(minLength: 0)
        Text("Pair a device in Sidekick to see it here.")
          .font(.system(size: 13))
          .foregroundStyle(wMuted)
        Spacer(minLength: 0)
      } else {
        ForEach(data.devices.prefix(3)) { device in
          HStack(spacing: 10) {
            Image(systemName: symbol(for: device.kind))
              .font(.system(size: 14))
              .foregroundStyle(device.online ? wText : wMuted)
              .frame(width: 30, height: 30)
              .background(RoundedRectangle(cornerRadius: 9).fill(wRaised))
            VStack(alignment: .leading, spacing: 1) {
              Text(device.name).font(.system(size: 14)).foregroundStyle(wText).lineLimit(1)
              Text(device.online ? "Ready" : "Not reachable")
                .font(.system(size: 11))
                .foregroundStyle(device.online ? wOk : wMuted)
            }
            Spacer(minLength: 4)
            Link(destination: link("send", device.id)) {
              Text("Send")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(wOnWhite)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(wWhite))
            }
            Link(destination: link("ping", device.id)) {
              Text("Ping")
                .font(.system(size: 13))
                .foregroundStyle(wText)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(wRaised))
            }
          }
        }
        Spacer(minLength: 0)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .sidekickBackground()
    .widgetURL(link("open"))
  }

  private func symbol(for kind: String) -> String {
    switch kind {
    case "phone": return "iphone"
    case "laptop": return "laptopcomputer"
    default: return "desktopcomputer"
    }
  }
}
