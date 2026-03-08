// Filename: LLMServices.swift
import Foundation

enum LLMError: Error, LocalizedError {
    case invalidKey      // 401
    case quotaExceeded   // 429
    case accessDenied    // 403 (VPN/Region)
    case serverError(Int)// 5xx
    case networkError(Error)
    case decodingError(String)
    case emptyResponse
    case userCancelled   // 👈 新增：用户拒绝降级
    
    var errorDescription: String? {
        switch self {
        case .invalidKey: return "API Key 无效 (401)"
        case .quotaExceeded: return "配额超限/请求过快 (429)"
        case .accessDenied: return "访问被拒绝 (403)"
        case .serverError(let code): return "服务器错误 (\(code))"
        case .networkError(let err): return "网络连接失败: \(err.localizedDescription)"
        case .decodingError(let msg): return "解析失败: \(msg)"
        case .emptyResponse: return "AI 返回内容为空"
        case .userCancelled: return "已取消：拒绝使用低精度模型"
        }
    }
}

protocol LLMClient {
    // 👈 核心修改：增加了一个挂起的闭包 onDowngrade 用于询问 UI
    func send(prompt: String, text: String, apiKey: String, onLog: @escaping (AppLog) -> Void, onDowngrade: @escaping (String) async -> Bool) async throws -> String
}

// --- Groq Client ---
class GroqClient: LLMClient {
    func send(prompt: String, text: String, apiKey: String, onLog: @escaping (AppLog) -> Void, onDowngrade: @escaping (String) async -> Bool) async throws -> String {
        let url = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
        var request = URLRequest(url: url); request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [ "model": "llama-3.3-70b-versatile", "messages": [ ["role":"system","content":prompt], ["role":"user","content":text] ], "temperature": 0.1 ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await performRequest(request, isGoogle: false, onLog: onLog)
    }
}

// --- Google (纯血 Gemma 3) Client ---
class GemmaClient: LLMClient {
    
    // 降级判断：只有当 Key 错或没网时停止；配额超限(429)会触发降级
    private func shouldHalt(for error: LLMError) -> Bool {
        if case .invalidKey = error { return true }
        if case .accessDenied = error { return true }
        return false
    }

    func send(prompt: String, text: String, apiKey: String, onLog: @escaping (AppLog) -> Void, onDowngrade: @escaping (String) async -> Bool) async throws -> String {
        
        // 1. 尝试 12B (大概率会因为 Rate Limit 失败)
        do {
            onLog(AppLog(type: .info, message: "首选模型: Gemma 3 12B..."))
            return try await sendSingle(model: "gemma-3-12b-it", prompt: prompt, text: text, apiKey: apiKey, onLog: onLog)
        } catch let error as LLMError {
            if shouldHalt(for: error) { throw error }
            onLog(AppLog(type: .error, message: "12B 失败，无缝切换 27B..."))
        }
        
        // 2. 尝试 27B
        do {
            onLog(AppLog(type: .info, message: "备选模型: Gemma 3 27B..."))
            return try await sendSingle(model: "gemma-3-27b-it", prompt: prompt, text: text, apiKey: apiKey, onLog: onLog)
        } catch let error as LLMError {
            if shouldHalt(for: error) { throw error }
            onLog(AppLog(type: .error, message: "27B 失败，准备降级。"))
        }
        
        // 3. 询问并尝试 4B
        let proceedTo4B = await onDowngrade("4B")
        if !proceedTo4B { throw LLMError.userCancelled } // 阻塞并等待用户点击
        
        do {
            onLog(AppLog(type: .info, message: "降级模型: Gemma 3 4B..."))
            return try await sendSingle(model: "gemma-3-4b-it", prompt: prompt, text: text, apiKey: apiKey, onLog: onLog)
        } catch let error as LLMError {
            if shouldHalt(for: error) { throw error }
            onLog(AppLog(type: .error, message: "4B 失败，面临最终降级。"))
        }
        
        // 4. 询问并尝试 1B
        let proceedTo1B = await onDowngrade("1B")
        if !proceedTo1B { throw LLMError.userCancelled }
        
        do {
            onLog(AppLog(type: .info, message: "最终兜底: Gemma 3 1B..."))
            return try await sendSingle(model: "gemma-3-1b-it", prompt: prompt, text: text, apiKey: apiKey, onLog: onLog)
        } catch let error as LLMError {
            throw error // 1B也失败，直接抛出异常
        }
    }
    
    private func sendSingle(model: String, prompt: String, text: String, apiKey: String, onLog: @escaping (AppLog) -> Void) async throws -> String {
        let urlStr = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlStr) else { throw LLMError.networkError(NSError(domain: "URL", code: 0)) }
        var request = URLRequest(url: url); request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [ "contents": [ ["parts": [["text": text]]] ], "systemInstruction": [ "parts": [["text": prompt]] ] ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await performRequest(request, isGoogle: true, onLog: onLog)
    }
}

// --- 通用网络请求与错误映射 ---
private func performRequest(_ request: URLRequest, isGoogle: Bool, onLog: @escaping (AppLog) -> Void) async throws -> String {
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        if let raw = String(data: data, encoding: .utf8) { onLog(AppLog(type: .aiRaw, message: raw)) }
        if let h = response as? HTTPURLResponse {
            switch h.statusCode {
            case 200...299: break
            case 401: throw LLMError.invalidKey
            case 403: throw LLMError.accessDenied
            case 429: throw LLMError.quotaExceeded
            default: throw LLMError.serverError(h.statusCode)
            }
        }
        if isGoogle {
            let res = try JSONDecoder().decode(GoogleResponse.self, from: data)
            guard let txt = res.candidates?.first?.content.parts.first?.text else { throw LLMError.emptyResponse }
            return txt
        } else {
            let res = try JSONDecoder().decode(GroqAPIResponse.self, from: data)
            guard let txt = res.choices.first?.message.content else { throw LLMError.emptyResponse }
            return txt
        }
    } catch let error as LLMError { throw error } catch { throw LLMError.networkError(error) }
}

struct GroqAPIResponse: Decodable { struct Choice: Decodable { struct Message: Decodable { let content: String? }; let message: Message }; let choices: [Choice] }
struct GoogleResponse: Decodable { struct Candidate: Decodable { struct Content: Decodable { struct Part: Decodable { let text: String? }; let parts: [Part] }; let content: Content }; let candidates: [Candidate]? }
