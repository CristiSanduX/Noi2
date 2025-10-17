//
//  Noi2LoveWidget.swift
//  Noi2LoveWidget
//
//  Created by Cristi Sandu on 16.10.2025.
//

import WidgetKit
import SwiftUI

struct LoveEntry: TimelineEntry {
    let date: Date
    let note: LoveNote?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> LoveEntry {
        .init(date: .now, note: .init(text: "Connecting hearts…", fromUid: "", fromName: "Noi2", updatedAt: .now))
    }

    func getSnapshot(in context: Context, completion: @escaping (LoveEntry) -> Void) {
        completion(.init(date: .now, note: LoveStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LoveEntry>) -> Void) {
        let entry = LoveEntry(date: .now, note: LoveStore.load())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct LoveWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: LoveEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.note?.text ?? "Nothing yet…")
                    .font(.system(.caption, design: .rounded))
                    .lineLimit(2)
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                    Text(entry.note?.fromName ?? "❤️")
                }
                .font(.system(.caption2))
                .foregroundStyle(.secondary)
            }
            .widgetURL(URL(string: "noi2://open/couple"))
        case .accessoryInline:
            Text("❤️ \(entry.note?.text ?? "Nothing yet")")
        default:
            ZStack {
                LinearGradient(colors: [.black, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                VStack(spacing: 6) {
                    Text(entry.note?.text ?? "Nothing yet…")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    if let name = entry.note?.fromName, !name.isEmpty {
                        Text(name).font(.caption).opacity(0.85)
                    }
                }
                .foregroundStyle(.white)
                .padding()
            }
        }
    }
}

struct Noi2LoveWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Noi2LoveWidget", provider: Provider()) { entry in
            LoveWidgetView(entry: entry)
        }
        .configurationDisplayName("Partner message")
        .description("Shows the latest message from your partner on the Lock Screen.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .systemSmall])
    }
}
