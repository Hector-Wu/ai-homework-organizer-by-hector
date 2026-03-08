// Filename: HomeworkModels.swift
// 用途：定义所有数据结构 (数据库模型、AI响应模型、日志模型、Prompt管理器)

import Foundation
import SwiftData
import Combine // 👈 关键修复：必须引入 Combine 才能使用 @Published 和 ObservableObject

// MARK: - 1. 数据库模型：作业项
@Model
final class HomeworkItem {
    var id: UUID
    var subject: String      // 存储双语科目，如 "数学 Math"
    var content: String
    var specialNotes: String?
    var startDate: Date
    var endDate: Date
    var isCompleted: Bool
    var creationDate: Date
    
    // 标记是否在回收站 (nil表示正常，有日期表示在回收站)
    var deletedDate: Date?

    init(subject: String, content: String, specialNotes: String? = nil, startDate: Date, endDate: Date) {
        self.id = UUID()
        self.subject = subject
        self.content = content
        self.specialNotes = specialNotes
        self.startDate = startDate
        self.endDate = endDate
        self.isCompleted = false
        self.creationDate = Date()
        self.deletedDate = nil
    }
}

// MARK: - 2. AI 响应模型
struct AIHomeworkResponse: Codable {
    let subject_en: String?
    let subject_zh: String?
    let content: String
    let notes: String?
    let daysFromToday: Int?
    let dueHour: Int?
    let durationDays: Int?
}

// MARK: - 3. 日志模型
struct AppLog: Identifiable {
    let id = UUID()
    let timestamp = Date()
    let type: LogType
    let message: String
    
    enum LogType {
        case info, success, error, aiRaw
    }
}

// MARK: - 4. API 提供商枚举
enum APIProvider: String, CaseIterable, Identifiable {
    case groq = "Groq (Llama 3)"
    case gemini = "Google (Gemma 3)" 
    var id: String { self.rawValue }
}

// MARK: - 5. Prompt 管理器 (修复版)
class PromptManager: ObservableObject {
    static let shared = PromptManager()
    
    // 默认 Prompt 定义在这里
    static let defaultPromptText = """
    Role: Homework Parser.
    Task: Extract homework.
    Output Language: {{LANG}}.
    Context: Today is {{DATE}}.
    
    Rules:
    1. **SPLIT**: Separate multiple items.
    2. **SUBJECT**: Return 'subject_en' AND 'subject_zh'. Do NOT treat books/objects as subjects. If unknown, use "General/综合".
    3. **DATE**: 0=Today, 1=Tomorrow. Default 23:59 Today.
    4. **NOISE**: Ignore administrative tasks.
    
    Output: JSON Array ONLY.
    JSON: [{"subject_en":String, "subject_zh":String, "content":String, "notes":String?, "daysFromToday":Int?, "dueHour":Int?, "durationDays":Int?}]
    """
    
    @Published var customPrompt: String {
        didSet {
            UserDefaults.standard.set(customPrompt, forKey: "custom_system_prompt")
        }
    }
    
    init() {
        // 尝试读取，如果没有则使用默认值
        let saved = UserDefaults.standard.string(forKey: "custom_system_prompt") ?? ""
        if saved.isEmpty {
            self.customPrompt = Self.defaultPromptText
        } else {
            self.customPrompt = saved
        }
    }
    
    func getEffectivePrompt(lang: String) -> String {
        let weekday = Date().formatted(Date.FormatStyle().weekday(.wide))
        let dateStr = "\(Date().formatted(date: .numeric, time: .omitted)) (\(weekday))"
        
        return customPrompt
            .replacingOccurrences(of: "{{LANG}}", with: lang)
            .replacingOccurrences(of: "{{DATE}}", with: dateStr)
    }
    
    func resetToDefault() {
        self.customPrompt = Self.defaultPromptText
    }
}
