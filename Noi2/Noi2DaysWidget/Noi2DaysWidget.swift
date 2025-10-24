//
//  Noi2DaysWidget.swift
//  Noi2DaysWidget
//
//  Created by Cristi Sandu on 24.10.2025.
//

import WidgetKit
import SwiftUI

// MARK: - Entry
struct DaysEntry: TimelineEntry {
    let date: Date
    let startDate: Date?
    let image: UIImage?
    var days: Int {
        guard let start = startDate else { return 0 }
        let cal = Calendar.current
        let from = cal.startOfDay(for: start)
        let to = cal.startOfDay(for: date)
        return cal.dateComponents([.day], from: from, to: to).day ?? 0
    }
}

// MARK: - Provider
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> DaysEntry {
        .init(date: .now,
              startDate: Calendar.current.date(byAdding: .day, value: -42, to: .now),
              image: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (DaysEntry) -> Void) {
        completion(buildEntry(for: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DaysEntry>) -> Void) {
        let now = Date()
        let entry = buildEntry(for: now)

        // următoarea actualizare: puțin după miezul nopții (ca să crească „zilele”)
        let cal = Calendar.current
        let next = cal.nextDate(after: now,
                                matching: DateComponents(hour: 0, minute: 1),
                                matchingPolicy: .nextTimePreservingSmallerComponents)
                    ?? now.addingTimeInterval(60 * 60 * 4)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    // Citește din App Group (UserDefaults + fișier imagine)
    private func buildEntry(for date: Date) -> DaysEntry {
        let groupId = "group.ro.csx.Noi2x.shared" // <- EXACT ca în app
        let ud = UserDefaults(suiteName: groupId)

        var startDate: Date? = nil
        if let iso = ud?.string(forKey: "widget_anniversary_iso") {
            startDate = ISO8601DateFormatter().date(from: iso)
        }

        var image: UIImage? = nil
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupId) {
            let url = container.appendingPathComponent("widget_photo.jpg")
            if let data = try? Data(contentsOf: url) {
                image = UIImage(data: data)
            }
        }

        return .init(date: date, startDate: startDate, image: image)
    }
}

// MARK: - View
struct DaysWidgetEntryView: View {
    let entry: Provider.Entry

    var body: some View {
        ZStack {
            // Background: fotografia voastră sau gradient fallback
            if let img = entry.image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [Color.black.opacity(0.45), Color.black.opacity(0.15)],
                            startPoint: .bottom, endPoint: .top
                        )
                    )
            } else {
                LinearGradient(
                    colors: [
                        Color(.sRGB, red: 0.14, green: 0.09, blue: 0.16),
                        Color(.sRGB, red: 0.26, green: 0.10, blue: 0.18)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(entry.days)")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(.white)

                Text("days together")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.95))

                if let start = entry.startDate {
                    Text(start.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.top, 2)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .containerBackground(.clear, for: .widget)
        // Deep link către ecranul de Anniversary (pasul următor)
        .widgetURL(URL(string: "noi2://anniversary"))
    }
}

// MARK: - Widget
@main
struct Noi2DaysWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Noi2DaysWidget", provider: Provider()) { entry in
            DaysWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Days Together")
        .description("Your photo and days together.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
