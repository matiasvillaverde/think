import Foundation
import Testing

@Suite("CronExpression Tests")
struct CronExpressionTests {
    @Test("Parses wildcard expression")
    func parsesWildcardExpression() throws {
        let expression = try CronExpression("* * * * *")
        let calendar = Calendar(identifier: .gregorian)
        let base = Date(timeIntervalSince1970: 0)
        let next = expression.nextDate(after: base, calendar: calendar)
        #expect(next != nil)
    }

    @Test("Parses step expressions")
    func parsesStepExpressions() throws {
        let expression = try CronExpression("*/15 * * * *")
        let calendar = Calendar(identifier: .gregorian)
        let base = Date(timeIntervalSince1970: 0)
        let next = expression.nextDate(after: base, calendar: calendar)
        let minute = calendar.component(.minute, from: next ?? base)
        #expect([0, 15, 30, 45].contains(minute))
    }

    @Test("Parses ranges and lists")
    func parsesRangesAndLists() throws {
        let expression = try CronExpression("0 9-10 1,15 * 1-5")
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = 2025
        components.month = 1
        components.day = 1
        components.hour = 8
        components.minute = 59
        let base = calendar.date(from: components) ?? Date()
        let next = expression.nextDate(after: base, calendar: calendar)
        let nextHour = calendar.component(.hour, from: next ?? base)
        #expect(nextHour == 9)
    }

    @Test("Rejects invalid field counts")
    func rejectsInvalidFieldCounts() {
        #expect(throws: CronExpressionError.invalidFieldCount) {
            _ = try CronExpression("* * * *")
        }
    }

    @Test("Rejects out of bounds values")
    func rejectsOutOfBoundsValues() {
        #expect(throws: CronExpressionError.outOfBounds) {
            _ = try CronExpression("60 * * * *")
        }
    }
}
