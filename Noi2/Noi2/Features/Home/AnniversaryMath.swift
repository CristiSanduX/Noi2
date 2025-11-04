//
//  AnniversaryMath.swift
//  Noi2
//
//  Created by Cristi Sandu on 05.11.2025.
//


import Foundation

enum AnniversaryMath {
    static var cal: Calendar { 
        var c = Calendar.current
        return c
    }

    @inline(__always)
    static func startOfDay(_ d: Date) -> Date { cal.startOfDay(for: d) }

    static func daysSince(_ date: Date, inclusive: Bool = true) -> Int {
        var cal = Calendar.current
        cal.timeZone = TimeZone(secondsFromGMT: 0)!

        let from = cal.startOfDay(for: date)
        let to = cal.startOfDay(for: Date())

        var days = cal.dateComponents([.day], from: from, to: to).day ?? 0
        if inclusive { days += 1 } 
        return max(days, 0)
    }


    static func fullYearsSince(_ date: Date) -> Int {
        let from = startOfDay(date)
        let to   = startOfDay(Date())
        return cal.dateComponents([.year], from: from, to: to).year ?? 0
    }

    static func daysUntilNextAnniversary(since anniversary: Date) -> Int {
        let now  = startOfDay(Date())
        let ann  = startOfDay(anniversary)

        var md = cal.dateComponents([.month, .day], from: ann) // doar MM-dd
        let yearNow = cal.component(.year, from: now)

        var next = cal.date(from: DateComponents(year: yearNow, month: md.month, day: md.day))

        if next == nil, md.month == 2, md.day == 29 {
            next = cal.date(from: DateComponents(year: yearNow, month: 2, day: 28))
        }

        guard var nextDate = next else { return 0 }

        if nextDate < now {
            let nextYear = yearNow + 1
            nextDate = cal.date(from: DateComponents(year: nextYear, month: md.month, day: md.day))
                ?? cal.date(from: DateComponents(year: nextYear, month: 2, day: 28))!
        }

        return cal.dateComponents([.day], from: now, to: nextDate).day ?? 0
    }

    static func ymdSince(_ date: Date) -> DateComponents {
        let from = startOfDay(date)
        let to   = startOfDay(Date())
        return cal.dateComponents([.year, .month, .day], from: from, to: to)
    }
}
