import Foundation

enum BookingRentalUnit: String {
    case hour
    case day

    init(rawValue: String?) {
        let normalized = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self = normalized == "hour" ? .hour : .day
    }
}

struct BookingPresentation {
    let rentalUnit: BookingRentalUnit
    let pickupDateTime: Date
    let returnDateTime: Date
    let dateText: String
    let timeText: String
    let durationText: String
    let quantityUnits: Int
    let rentalFee: Double
}

enum BookingPresentationFormatter {
    static let sqlDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        // Requests store calendar dates, not absolute UTC instants.
        // Using the current timezone preserves the exact local day the user selected.
        df.timeZone = .current
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    private static let displayDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.timeZone = .current
        df.dateFormat = "d MMM yyyy"
        return df
    }()

    private static let displayTimeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .none
        df.timeStyle = .short
        return df
    }()

    private static let sqlTimeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.timeZone = .current
        df.dateFormat = "HH:mm:ssXXXXX"
        return df
    }()

    private static let fallbackTimeParsers: [DateFormatter] = {
        ["HH:mm:ss", "HH:mm"].map { format in
            let df = DateFormatter()
            df.calendar = Calendar(identifier: .gregorian)
            df.timeZone = .current
            df.dateFormat = format
            return df
        }
    }()

    static func presentation(
        startDate: Date,
        pickupTime: Date,
        returnSelection: Date,
        rentalUnit: BookingRentalUnit,
        pricePerDay: Double,
        calendar: Calendar = .current
    ) -> BookingPresentation {
        let pickupDateTime = combine(date: startDate, time: pickupTime, calendar: calendar)
        let returnDateTime: Date

        switch rentalUnit {
        case .hour:
            var candidate = combine(date: startDate, time: returnSelection, calendar: calendar)
            if candidate <= pickupDateTime {
                candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
            }
            returnDateTime = candidate
        case .day:
            var candidate = combine(date: returnSelection, time: pickupTime, calendar: calendar)
            if candidate < pickupDateTime {
                candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
            }
            returnDateTime = candidate
        }

        return presentation(
            pickupDateTime: pickupDateTime,
            returnDateTime: returnDateTime,
            rentalUnit: rentalUnit,
            pricePerDay: pricePerDay
        )
    }

    static func presentation(from request: RequestWithItem, pricePerDay: Double) -> BookingPresentation? {
        guard let startDate = sqlDateFormatter.date(from: request.start_date) else {
            return nil
        }

        let rentalUnit = BookingRentalUnit(rawValue: request.rental_unit)
        let pickupTime = parseTime(request.pickup_time) ?? startDate
        let pickupDateTime = combine(date: startDate, time: pickupTime)

        let returnDateTime: Date
        switch rentalUnit {
        case .hour:
            let dayDate = sqlDateFormatter.date(from: request.end_date) ?? startDate
            let returnTime = parseTime(request.return_time) ?? pickupTime
            var candidate = combine(date: dayDate, time: returnTime)
            if candidate <= pickupDateTime {
                candidate = Calendar.current.date(byAdding: .day, value: 1, to: candidate) ?? candidate
            }
            returnDateTime = candidate
        case .day:
            let endDate = sqlDateFormatter.date(from: request.end_date) ?? startDate
            var candidate = combine(date: endDate, time: pickupTime)
            if candidate < pickupDateTime {
                candidate = Calendar.current.date(byAdding: .day, value: 1, to: candidate) ?? candidate
            }
            returnDateTime = candidate
        }

        return presentation(
            pickupDateTime: pickupDateTime,
            returnDateTime: returnDateTime,
            rentalUnit: rentalUnit,
            pricePerDay: pricePerDay
        )
    }

    static func sqlDateString(for date: Date) -> String {
        sqlDateFormatter.string(from: Calendar.current.startOfDay(for: date))
    }

    static func sqlDate(from rawValue: String) -> Date? {
        sqlDateFormatter.date(from: rawValue)
    }

    static func sqlTimeString(for date: Date) -> String {
        sqlTimeFormatter.string(from: date)
    }

    static func displayDateString(for date: Date) -> String {
        displayDateFormatter.string(from: date)
    }

    static func displayTimeString(for date: Date) -> String {
        displayTimeFormatter.string(from: date)
    }

    static func combine(date: Date, time: Date, calendar: Calendar = .current) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = timeComponents.second
        return calendar.date(from: components) ?? date
    }

    static func parseTime(_ raw: String?) -> Date? {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        if let parsed = sqlTimeFormatter.date(from: raw) {
            return parsed
        }

        for formatter in fallbackTimeParsers {
            if let parsed = formatter.date(from: raw) {
                return parsed
            }
        }

        return nil
    }

    static func presentation(
        pickupDateTime: Date,
        returnDateTime: Date,
        rentalUnit: BookingRentalUnit,
        pricePerDay: Double
    ) -> BookingPresentation {
        let duration = max(0, returnDateTime.timeIntervalSince(pickupDateTime))
        let quantityUnits: Int
        let rentalFee: Double
        let dateText: String
        let timeText: String
        let durationText: String

        switch rentalUnit {
        case .hour:
            quantityUnits = max(1, Int(ceil(duration / 3600.0)))
            let hourlyRate = rounded(pricePerDay / 8.0, places: 2)
            rentalFee = Double(quantityUnits) * hourlyRate
            dateText = displayDateFormatter.string(from: pickupDateTime)
            timeText = "\(displayTimeFormatter.string(from: pickupDateTime)) — \(displayTimeFormatter.string(from: returnDateTime))"
            durationText = "\(quantityUnits) Hour\(quantityUnits == 1 ? "" : "s")"
        case .day:
            quantityUnits = max(1, Int(ceil(duration / 86400.0)))
            rentalFee = Double(quantityUnits) * pricePerDay
            if Calendar.current.isDate(pickupDateTime, inSameDayAs: returnDateTime) {
                dateText = displayDateFormatter.string(from: pickupDateTime)
            } else {
                dateText = "\(displayDateFormatter.string(from: pickupDateTime)) — \(displayDateFormatter.string(from: returnDateTime))"
            }
            timeText = displayTimeFormatter.string(from: pickupDateTime)
            durationText = "\(quantityUnits) Day\(quantityUnits == 1 ? "" : "s")"
        }

        return BookingPresentation(
            rentalUnit: rentalUnit,
            pickupDateTime: pickupDateTime,
            returnDateTime: returnDateTime,
            dateText: dateText,
            timeText: timeText,
            durationText: durationText,
            quantityUnits: quantityUnits,
            rentalFee: rentalFee
        )
    }

    private static func rounded(_ value: Double, places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return Darwin.round(value * divisor) / divisor
    }
}
