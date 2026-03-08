// Filename: HomeworkLogic.swift
// 用途：处理 Groq API 请求、Prompt 逻辑、JSON 解析与清洗

import Foundation
import SwiftData
import SwiftUI

enum HomeworkError: Error, LocalizedError {
    case apiKeyMissing
    case apiError(Int, String)
    case networkError(Error)
    case decodingError(String)
    
    var errorDescription: String? {
        switch self {
        case .apiKeyMissing: return "未填写 API Key"
        case .apiError(let code, let msg): return "API Error \(code): \(msg)"
        case .networkError(let err): return "网络错误: \(err.localizedDescription)"
        case .decodingError(let detail): return "解析失败: \(detail)"
        }
    }
}

class HomeworkManager {
    private var apiKey: String? {
        UserDefaults.standard.string(forKey: "user_groq_api_key")
    }
    
    @MainActor
    func processInput(text: String, outputLang: String, modelContext: ModelContext, onLog: @escaping (AppLog) -> Void) async throws {
        guard let key = apiKey, !key.isEmpty else { throw HomeworkError.apiKeyMissing }
        guard !text.isEmpty else { return }
        
        onLog(AppLog(type: .info, message: "发送: \(text)"))
        
        guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let weekday = Date().formatted(Date.FormatStyle().weekday(.wide))
        
        // 加强对“学科”的定义，防止把书名当学科
        let systemPrompt = """
        Role: Homework Parser.
        Task: Extract homework.
        Context: Today is \(Date().formatted(date: .numeric, time: .omitted)) (\(weekday)).
        Output Language Preference: \(outputLang).
        
        Rules:
        1. **SPLIT TASKS**: Return separate objects for multiple items.
        2. **SUBJECT IDENTIFICATION**:
           - STRICTLY identify academic subjects (e.g., Math, Physics, English, History).
           - ⛔️ CRITICAL: Do NOT treat book titles, objects, or colors as subjects (e.g., "Purple Workbook", "Paper", "Exercise Book" are NOT subjects).
           - If no standard subject is found, use subject_en="General", subject_zh="综合".
        3. **CONTENT**: The 'content' field must include the specific object/book and pages (e.g., "Purple Workbook p62-69").
        4. **Date**: 0=Today, 1=Tomorrow. Default: Today 23:59.
        
        Output: STRICT JSON Array.
        JSON Structure: [{"subject_en":String, "subject_zh":String, "content":String, "notes":String?, "daysFromToday":Int?, "dueHour":Int?, "durationDays":Int?}]
        """
        
        let body: [String: Any] = [
            "model": "llama-3.3-70b-versatile",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.1
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let rawString = String(data: data, encoding: .utf8) {
                onLog(AppLog(type: .aiRaw, message: rawString))
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    throw HomeworkError.apiError(httpResponse.statusCode, "Check Key or Quota")
                }
            }
            
            let apiResponse = try JSONDecoder().decode(GroqAPIResponse.self, from: data)
            guard let contentString = apiResponse.choices.first?.message.content else {
                throw HomeworkError.decodingError("Empty Content")
            }
            
            let cleanJson = contentString
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard let jsonData = cleanJson.data(using: .utf8) else {
                throw HomeworkError.decodingError("Data Convert Failed")
            }
            
            let tasks = try JSONDecoder().decode([AIHomeworkResponse].self, from: jsonData)
            
            // 🚀 智能归一化 (逻辑保持不变)
            let existingSubjects = try fetchAllSubjects(context: modelContext)
            
            var count = 0
            for task in tasks {
                let en = task.subject_en ?? ""
                let zh = task.subject_zh ?? ""
                var rawSubject = "\(zh) \(en)".trimmingCharacters(in: .whitespaces)
                
                // 再次兜底：如果 AI 还是发疯返回了空，强制设为综合
                if rawSubject.isEmpty { rawSubject = "综合 General" }
                
                let finalSubject = normalizeSubject(raw: rawSubject, existing: existingSubjects)
                
                if saveTask(task, subjectName: finalSubject, context: modelContext) { count += 1 }
            }
            onLog(AppLog(type: .success, message: "保存 \(count) 个任务"))
            
        } catch let error as DecodingError {
            onLog(AppLog(type: .error, message: "JSON解析错: \(error)"))
            throw HomeworkError.decodingError("格式错: \(error.localizedDescription)")
        } catch let error as HomeworkError {
            throw error
        } catch {
            throw HomeworkError.networkError(error)
        }
    }
    
    private func fetchAllSubjects(context: ModelContext) throws -> [String] {
        let descriptor = FetchDescriptor<HomeworkItem>(sortBy: [SortDescriptor(\.subject)])
        let items = try context.fetch(descriptor)
        return Array(Set(items.map { $0.subject }))
    }
    
    private func normalizeSubject(raw: String, existing: [String]) -> String {
        if existing.contains(raw) { return raw }
        let keywords = raw.split(separator: " ").map { String($0).lowercased() }
        for exist in existing {
            let existLower = exist.lowercased()
            for keyword in keywords {
                if keyword.count > 1 && existLower.contains(keyword) {
                    return exist
                }
            }
        }
        return raw
    }
    
    @MainActor
    private func saveTask(_ task: AIHomeworkResponse, subjectName: String, context: ModelContext) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var components = DateComponents()
        
        let daysOffset = task.daysFromToday ?? 0
        let duration = task.durationDays ?? 1
        
        components.day = daysOffset + (duration > 1 ? duration - 1 : 0)
        components.hour = task.dueHour ?? 23
        components.minute = task.dueHour != nil ? 0 : 59
        let end = calendar.date(byAdding: components, to: today) ?? today
        
        do {
            let descriptor = FetchDescriptor<HomeworkItem>(
                predicate: #Predicate { item in
                    item.subject == subjectName &&
                    item.content == task.content &&
                    item.deletedDate == nil
                }
            )
            let existing = try context.fetch(descriptor)
            if existing.contains(where: { calendar.isDate($0.endDate, inSameDayAs: end) }) { return false }
            
            let newItem = HomeworkItem(
                subject: subjectName,
                content: task.content,
                specialNotes: task.notes,
                startDate: today,
                endDate: end
            )
            context.insert(newItem)
            return true
        } catch { return false }
    }
}

struct GroqAPIResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String? }
        let message: Message
    }
    let choices: [Choice]
}
