//
//  HomeworkAssistantApp.swift
//  Homework assistant
//
//  Created by Hector Wu on 3/3/2026.
//


import SwiftUI
import SwiftData

@main
struct HomeworkAssistantApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // 这一行非常重要，注入数据库容器
        .modelContainer(for: HomeworkItem.self)
    }
}