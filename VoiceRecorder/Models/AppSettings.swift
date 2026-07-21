import Foundation

enum QuestionMode: String, CaseIterable, Identifiable {
    case random
    case sequential

    var id: String { rawValue }
    var label: String { self == .random ? "Random" : "In order" }
}

final class AppSettings: ObservableObject {
    static let durationOptions = [20, 30, 45, 60, 90, 120, 180, 240, 300]

    @Published var recordingLimit: Int {
        didSet { UserDefaults.standard.set(recordingLimit, forKey: Keys.recordingLimit) }
    }

    @Published var questionMode: QuestionMode {
        didSet { UserDefaults.standard.set(questionMode.rawValue, forKey: Keys.questionMode) }
    }

    @Published var questions: [String] {
        didSet { UserDefaults.standard.set(questions, forKey: Keys.questions) }
    }

    @Published private(set) var sequentialIndex: Int {
        didSet { UserDefaults.standard.set(sequentialIndex, forKey: Keys.sequentialIndex) }
    }

    private enum Keys {
        static let recordingLimit = "recordingLimit"
        static let questionMode = "questionMode"
        static let questions = "questions"
        static let sequentialIndex = "sequentialIndex"
    }

    init() {
        let savedLimit = UserDefaults.standard.integer(forKey: Keys.recordingLimit)
        recordingLimit = Self.durationOptions.contains(savedLimit) ? savedLimit : 45

        let savedMode = UserDefaults.standard.string(forKey: Keys.questionMode) ?? QuestionMode.random.rawValue
        questionMode = QuestionMode(rawValue: savedMode) ?? .random

        questions = UserDefaults.standard.stringArray(forKey: Keys.questions) ?? [
            "What do you love most about your city?",
            "Which neighborhood should every visitor see?",
            "What sound reminds you of your city?",
            "Where is the best place to watch the sunset?"
        ]
        sequentialIndex = UserDefaults.standard.integer(forKey: Keys.sequentialIndex)
    }

    var previewQuestion: String {
        cleanedQuestions.first ?? "Tell us something about your city."
    }

    func nextQuestion() -> String {
        let cleaned = cleanedQuestions
        guard !cleaned.isEmpty else { return "Tell us something about your city." }

        switch questionMode {
        case .random:
            return cleaned.randomElement() ?? cleaned[0]
        case .sequential:
            let question = cleaned[sequentialIndex % cleaned.count]
            sequentialIndex = (sequentialIndex + 1) % cleaned.count
            return question
        }
    }

    private var cleanedQuestions: [String] {
        questions.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}
