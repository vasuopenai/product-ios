/// What this phone has asked and scanned, newest first, kept in UserDefaults. Shown on the Ask
/// home so a shopper can re-ask a question or reopen a product without scanning it again.

import Foundation
import FoodGenieKit

@MainActor
@Observable
final class History {
    private(set) var questions: [String] = []
    private(set) var scans: [RecentScan] = []

    private static let questionsKey = "recent-questions"
    private static let scansKey = "recent-scans"
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        questions = defaults.stringArray(forKey: Self.questionsKey) ?? []
        if let data = defaults.data(forKey: Self.scansKey) {
            scans = (try? JSONDecoder().decode([RecentScan].self, from: data)) ?? []
        }
    }

    // MARK: Questions

    func addQuestion(_ text: String) {
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        // The same question in different capitalization is one entry.
        questions = Recents.adding(q, to: questions, by: { $0.lowercased() })
        saveQuestions()
    }

    func removeQuestion(_ q: String) {
        questions.removeAll { $0 == q }
        saveQuestions()
    }

    func clearQuestions() {
        questions = []
        saveQuestions()
    }

    // MARK: Scans

    func addScan(_ product: Product) {
        scans = Recents.adding(RecentScan(product), to: scans, by: \.code)
        saveScans()
    }

    func removeScan(_ code: String) {
        scans.removeAll { $0.code == code }
        saveScans()
    }

    func clearScans() {
        scans = []
        saveScans()
    }

    // MARK: Storage

    private func saveQuestions() {
        defaults.set(questions, forKey: Self.questionsKey)
    }

    private func saveScans() {
        if let data = try? JSONEncoder().encode(scans) { defaults.set(data, forKey: Self.scansKey) }
    }
}
