import Foundation
import CoreGraphics

/// Represents a calendar in the user's calendar system.
struct AppCalendar: Identifiable {
    let id: String
    let title: String
    let canAddEvents: Bool
    let canEditEvents: Bool
    let canDeleteEvents: Bool
    let canReadEvents: Bool
    let color: CGColor
}

struct RecurrenceRule {
    enum RecurrenceFrequency {
        case daily
        case weekly
        case monthly
        case yearly
    }

    struct DayOfWeek {
        let dayOfTheWeek: Int // 1 = Sunday, 2 = Monday, etc.
        let weekNumber: Int // 1 = First week, 2 = Second week, etc.
    }
    let frequency: RecurrenceFrequency
    let interval: Int
    let daysOfTheWeek: [DayOfWeek]?
    let daysOfTheMonth: [Int]?
    let weeksOfTheYear: [Int]?
    let daysOfTheYear: [Int]?
    let setPositions: [Int]?
    let endDate: Date?
}

struct CalendarEvent: Identifiable, Comparable {
    static func < (lhs: CalendarEvent, rhs: CalendarEvent) -> Bool {
        if lhs.startDate != rhs.startDate {
            return lhs.startDate < rhs.startDate
        }
        return lhs.endDate < rhs.endDate
    }
    
    static func == (lhs: CalendarEvent, rhs: CalendarEvent) -> Bool {
        return lhs.id == rhs.id
    }
    
    let id: String
    let calendar: AppCalendar

    var title: String
    var timeZone: TimeZone?
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var location: String?
    var notes: String?

    // Recurrences
    var isRecurring: Bool
    var recurrenceOriginalDate: Date!
    var recurrenceEndDate: Date!
    var recurrenceIsDetached: Bool! // indicates if the event has been modified from the original recurring event
    var recurrenceRules: [RecurrenceRule]
    
    // TODO: Alarms. Not supported in this version yet.

    // Attendees, Guests, Accepting events, etc. are not supported. 
}

enum RecurringEventEditScope {
    case thisAndFuture
    case onlyThis
}

protocol CalendarProvider {
    func getCalendars() async throws -> [AppCalendar]
    func getDefaultCalendar() async -> AppCalendar
    func getEvents(for calendar: AppCalendar, startDate: Date, endDate: Date, limit: Int?) async throws -> [CalendarEvent]
    func getEvent(with id: String) async throws -> CalendarEvent?
    func createEvent(with event: CalendarEvent) async throws -> CalendarEvent
    func updateEvent(with event: CalendarEvent, recurrenceEditingScope: RecurringEventEditScope?) async throws -> CalendarEvent
    func deleteEvent(in calendar: AppCalendar, id: String) async throws
}

extension CalendarProvider {
    func getAllEvents(startDate: Date, endDate: Date, limit: Int?) async throws -> [CalendarEvent] {
        return try await withThrowingTaskGroup(of: [CalendarEvent].self, returning: [CalendarEvent].self) { taskGroup in
            for calendar in try await getCalendars() {
                taskGroup.addTask {
                    return try await getEvents(for: calendar, startDate: startDate, endDate: endDate, limit: limit)
                }
            }
            
            var results: [CalendarEvent] = []
            for try await events in taskGroup {
                results.append(contentsOf: events)
            }
            results.sort()
            
            if let limit = limit {
                if results.count > limit {
                    results = Array(results[..<limit])
                }
            }
            
            return results
        }
    }
}
