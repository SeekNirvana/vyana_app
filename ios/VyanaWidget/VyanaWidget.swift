import WidgetKit
import SwiftUI

// Shared container with the Runner app. Must match `HomeWidgetService.appGroupId`
// in Dart and the App Group added to BOTH the Runner and this extension target.
private let appGroupId = "group.com.seeknirvana.vyana"

// Brand palette (mirrors lib/src/theme/app_colors.dart).
private let vyanaBg = Color(red: 17 / 255, green: 24 / 255, blue: 21 / 255)
private let vyanaGold = Color(red: 201 / 255, green: 162 / 255, blue: 39 / 255)
private let vyanaGreen = Color(red: 0 / 255, green: 168 / 255, blue: 107 / 255)
private let vyanaAmber = Color(red: 224 / 255, green: 138 / 255, blue: 75 / 255)

private func toneColor(_ tone: String) -> Color {
  switch tone {
  case "good": return vyanaGreen
  case "steady": return vyanaGold
  case "watch": return vyanaAmber
  default: return Color.white.opacity(0.4)
  }
}

// MARK: - Data

struct VyanaEntry: TimelineEntry {
  let date: Date
  let title: String
  let line: String
  let updated: String
  let tone: String
  let hasData: Bool
  let biomarkers: [(label: String, value: String)]
}

private func loadEntry() -> VyanaEntry {
  let defaults = UserDefaults(suiteName: appGroupId)
  let title = defaults?.string(forKey: "state_title") ?? "Let's check in"
  let line = defaults?.string(forKey: "state_line") ?? ""
  let summary = defaults?.string(forKey: "state_summary") ?? "Tap to read your vitals"
  let updated = defaults?.string(forKey: "updated_label") ?? "Tap to check in"
  let tone = defaults?.string(forKey: "state_tone") ?? "unknown"
  let hasData = defaults?.bool(forKey: "has_data") ?? false

  var biomarkers: [(label: String, value: String)] = []
  for i in 0..<6 {
    let label = defaults?.string(forKey: "bio\(i)_label") ?? ""
    let value = defaults?.string(forKey: "bio\(i)_value") ?? ""
    if !value.isEmpty { biomarkers.append((label: label, value: value)) }
  }

  return VyanaEntry(
    date: Date(),
    title: title,
    line: line.isEmpty ? summary : line,
    updated: updated,
    tone: tone,
    hasData: hasData,
    biomarkers: biomarkers
  )
}

struct VyanaProvider: TimelineProvider {
  func placeholder(in context: Context) -> VyanaEntry { loadEntry() }

  func getSnapshot(in context: Context, completion: @escaping (VyanaEntry) -> Void) {
    completion(loadEntry())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<VyanaEntry>) -> Void) {
    // The app reloads timelines after every sync; refresh hourly as a fallback.
    let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date())
      ?? Date().addingTimeInterval(3600)
    completion(Timeline(entries: [loadEntry()], policy: .after(next)))
  }
}

// MARK: - Background helper (iOS 17 containerBackground / older fallback)

private extension View {
  @ViewBuilder
  func vyanaBackground(_ color: Color) -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      self.containerBackground(color, for: .widget)
    } else {
      self.background(color)
    }
  }
}

// MARK: - Views

struct VyanaVitalsView: View {
  @Environment(\.widgetFamily) private var family
  var entry: VyanaEntry

  private var showGrid: Bool { family != .systemSmall && !entry.biomarkers.isEmpty }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .firstTextBaseline) {
        Text("STATE OF BEING")
          .font(.system(size: 10, weight: .bold))
          .kerning(1.4)
          .foregroundColor(vyanaGold)
        Spacer()
        HStack(spacing: 5) {
          Circle().fill(toneColor(entry.tone)).frame(width: 6, height: 6)
          Text(entry.updated)
            .font(.system(size: 10))
            .foregroundColor(.white.opacity(0.45))
        }
      }
      Text(entry.title)
        .font(.system(size: 20, weight: .bold))
        .foregroundColor(.white)
        .lineLimit(1)

      if showGrid {
        let columns = Array(
          repeating: GridItem(.flexible(), alignment: .leading),
          count: 3
        )
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
          ForEach(0..<entry.biomarkers.count, id: \.self) { i in
            VStack(alignment: .leading, spacing: 1) {
              Text(entry.biomarkers[i].value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
              Text(entry.biomarkers[i].label)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.55))
                .lineLimit(1)
            }
          }
        }
        Spacer(minLength: 0)
      } else {
        Text(entry.line)
          .font(.system(size: 13))
          .foregroundColor(.white.opacity(0.7))
          .lineLimit(2)
        Spacer(minLength: 4)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .vyanaBackground(vyanaBg)
    .widgetURL(URL(string: "vyanawidget://open"))
  }
}

struct VyanaMonitorView: View {
  var entry: VyanaEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("MONITOR")
        .font(.system(size: 10, weight: .bold))
        .kerning(1.4)
        .foregroundColor(vyanaGold)
      Text("All vitals")
        .font(.system(size: 20, weight: .bold))
        .foregroundColor(.white)
      Spacer(minLength: 6)
      Text("Check in now")
        .font(.system(size: 14, weight: .bold))
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(vyanaGreen)
        .clipShape(RoundedRectangle(cornerRadius: 14))
      Text(entry.updated)
        .font(.system(size: 10))
        .foregroundColor(.white.opacity(0.45))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .vyanaBackground(vyanaBg)
    .widgetURL(URL(string: "vyanawidget://monitor"))
  }
}

// MARK: - Widgets

struct VyanaVitalsWidget: Widget {
  // `kind` must equal the iOSName passed from Dart (HomeWidgetService).
  let kind = "VyanaWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: VyanaProvider()) { entry in
      VyanaVitalsView(entry: entry)
    }
    .configurationDisplayName("Vyana · State of being")
    .description("Your state of being and latest biomarkers at a glance.")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }
}

struct VyanaMonitorWidget: Widget {
  let kind = "VyanaMonitorWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: VyanaProvider()) { entry in
      VyanaMonitorView(entry: entry)
    }
    .configurationDisplayName("Vyana · Monitor all vitals")
    .description("One tap to monitor all your vitals.")
    .supportedFamilies([.systemSmall])
  }
}

@main
struct VyanaWidgetBundle: WidgetBundle {
  var body: some Widget {
    VyanaVitalsWidget()
    VyanaMonitorWidget()
  }
}
