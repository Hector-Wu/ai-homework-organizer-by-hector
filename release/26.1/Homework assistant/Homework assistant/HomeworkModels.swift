// Filename: HomeworkModels.swift
// 用途：定义所有数据结构 (数据库模型、AI响应模型、日志模型)

import Foundation
import SwiftData

// 1. 数据库模型：作业项
@Model
final class HomeworkItem {
    var id: UUID
    var subject: String
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

// 2. AI 响应模型 (修复版)
// 将可能缺失的字段设为可选，防止解析失败
struct AIHomeworkResponse: Codable {
    let subject_en: String? // AI偶尔可能只返回一个名字
    let subject_zh: String?
    let content: String
    let notes: String?
    let daysFromToday: Int? // 如果没返回，默认0
    let dueHour: Int?
    let durationDays: Int?  // 关键修复：设为可选，如果没返回，默认1
}

// 3. 日志模型
struct AppLog: Identifiable {
    let id = UUID()
    let timestamp = Date()
    let type: LogType
    let message: String
    
    enum LogType {
        case info, success, error, aiRaw
    }
}
