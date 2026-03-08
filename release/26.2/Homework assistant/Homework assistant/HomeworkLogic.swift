// Filename: HomeworkLogic.swift
// 用途：业务逻辑层，连接 UI 与 LLM 服务，负责数据入库

import Foundation
import SwiftData
import SwiftUI

class HomeworkManager {
    private var groqKey: String? { UserDefaults.standard.string(forKey: "user_groq_api_key") }
    private var googleKey: String? { UserDefaults.standard.string(forKey: "user_google_api_key") }
    
    private var preferredProvider: APIProvider {
        if let raw = UserDefaults.standard.string(forKey: "preferred_api_provider"),
           let p = APIProvider(rawValue: raw) {
            return p
        }
        return .groq
    }
    
    private let groqClient = GroqClient()
    private let gemmaClient = GemmaClient()
    
    @MainActor
    func processInput(
        text: String,
        outputLang: String,
        modelContext: ModelContext,
        onLog: @escaping (AppLog) -> Void,
        onDowngrade: @escaping (String) async -> Bool
    ) async throws {
        var provider = preferredProvider
        
        if (groqKey == nil || groqKey!.isEmpty) && (googleKey != nil && !googleKey!.isEmpty) {
            provider = .gemini
        }
        if (googleKey == nil || googleKey!.isEmpty) && (groqKey != nil && !groqKey!.isEmpty) {
            provider = .groq
        }
        
        let activeKey = (provider == .groq ? groqKey : googleKey)
        guard let key = activeKey, !key.isEmpty else {
            throw LLMError.invalidKey
        }
        
        let engineName = provider == .groq ? "Groq (Llama 3)" : "Google (Gemma 3)"
        onLog(AppLog(type: .info, message: "Engine: \(engineName)"))
        
        let systemPrompt = PromptManager.shared.getEffectivePrompt(lang: outputLang)
        
        let jsonString: String
        if provider == .groq {
            jsonString = try await groqClient.send(
                prompt: systemPrompt,
                text: text,
                apiKey: key,
                onLog: onLog,
                onDowngrade: onDowngrade
            )
        } else {
            jsonString = try await gemmaClient.send(
                prompt: systemPrompt,
                text: text,
                apiKey: key,
                onLog: onLog,
                onDowngrade: onDowngrade
            )
        }
        
        try parseAndSave(jsonString: jsonString, modelContext: modelContext, onLog: onLog)
    }
    
    @MainActor
    private func parseAndSave(jsonString: String, modelContext: ModelContext, onLog: @escaping (AppLog) -> Void) throws {
        let clean = jsonString
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = clean.data(using: .utf8) else {
            throw LLMError.decodingError("Data Error")
        }
        
        let tasks = try JSONDecoder().decode([AIHomeworkResponse].self, from: data)
        let existing = try fetchAllSubjects(context: modelContext)
        
        var count = 0
        for task in tasks {
            let en = task.subject_en ?? ""
            let zh = task.subject_zh ?? ""
            var sub = "\(zh) \(en)".trimmingCharacters(in: .whitespaces)
            
            if sub.isEmpty {
                if !zh.isEmpty {
                    sub = zh
                } else if !en.isEmpty {
                    sub = en
                } else {
                    sub = "综合 General"
                }
            }
            
            let normalized = normalize(raw: sub, existing: existing)
            if save(task: task, subject: normalized, context: modelContext) {
                count += 1
            }
        }
        
        onLog(AppLog(type: .success, message: "Saved \(count) tasks"))
    }
    
    private func fetchAllSubjects(context: ModelContext) throws -> [String] {
        let items = try context.fetch(FetchDescriptor<HomeworkItem>())
        return Array(Set(items.map { $0.subject }))
    }
    
    private func normalize(raw: String, existing: [String]) -> String {
        if existing.contains(raw) { return raw }
        let keys = raw.split(separator: " ").map { String($0).lowercased() }
        for exist in existing {
            let existLower = exist.lowercased()
            for k in keys {
                if k.count > 1 && existLower.contains(k) {
                    return exist
                }
            }
        }
        return raw
    }
    
    @MainActor
    private func save(task: AIHomeworkResponse, subject: String, context: ModelContext) -> Bool {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var comp = DateComponents()
        comp.day = (task.daysFromToday ?? 0) + ((task.durationDays ?? 1) > 1 ? (task.durationDays ?? 1) - 1 : 0)
        comp.hour = task.dueHour ?? 23
        comp.minute = task.dueHour != nil ? 0 : 59
        
        let end = cal.date(byAdding: comp, to: today) ?? today
        
        let desc = FetchDescriptor<HomeworkItem>(
            predicate: #Predicate {
                $0.subject == subject && $0.content == task.content && $0.deletedDate == nil
            }
        )
        
        if (try? context.fetch(desc).count) ?? 0 > 0 {
            return false
        }
        
        context.insert(
            HomeworkItem(
                subject: subject,
                content: task.content,
                specialNotes: task.notes,
                startDate: today,
                endDate: end
            )
        )
        return true
    }
}
