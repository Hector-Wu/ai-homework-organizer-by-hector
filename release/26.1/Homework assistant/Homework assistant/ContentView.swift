// Filename: ContentView.swift
// 用途：主界面、所有 UI 组件、枚举定义、颜色管理

import SwiftUI
import SwiftData
import Combine

// MARK: - 1. 全局定义

enum AppLanguage: String, CaseIterable, Identifiable {
    case chinese = "zh-Hans"
    case english = "en"
    var id: String { self.rawValue }
    var displayName: String {
        switch self {
        case .chinese: return "中文 (Chinese)"
        case .english: return "English"
        }
    }
}

enum OutputLanguage: String, CaseIterable, Identifiable {
    case chinese = "Chinese"
    case english = "English"
    var id: String { self.rawValue }
    var displayName: String {
        switch self {
        case .chinese: return "中文"
        case .english: return "English"
        }
    }
}

enum ClearActionType { case dataOnly; case both }

// MARK: - 2. 学科与颜色管理器
class SubjectManager: ObservableObject {
    @Published var subjectColors: [String: String] = [:]
    @Published var manuallyAddedSubjects: Set<String> = []
    
    init() { load() }
    
    func load() {
        if let data = UserDefaults.standard.data(forKey: "subjectColors"),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            self.subjectColors = decoded
        } else { self.subjectColors = [:] }
        
        if let data = UserDefaults.standard.data(forKey: "manualSubjects"),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            self.manuallyAddedSubjects = decoded
        } else { self.manuallyAddedSubjects = [] }
    }
    
    private let palette: [Color] = [.blue, .orange, .green, .purple, .pink, .teal, .indigo, .mint, .cyan, .brown]
    
    func getColor(for subject: String) -> Color {
        if let hex = subjectColors[subject] { return Color(hex: hex) }
        let usedHexes = Set(subjectColors.values)
        var newColor = palette.randomElement()!
        for color in palette { if !usedHexes.contains(color.toHex() ?? "") { newColor = color; break } }
        let hex = newColor.toHex() ?? "#0000FF"; subjectColors[subject] = hex; save(); return newColor
    }
    func setColor(for subject: String, color: Color) { subjectColors[subject] = color.toHex(); save() }
    func addSubject(_ name: String) { manuallyAddedSubjects.insert(name); save() }
    func removeSubject(_ name: String) { manuallyAddedSubjects.remove(name); save() }
    func renameSubject(from old: String, to new: String) {
        if let colorHex = subjectColors[old] { subjectColors[new] = colorHex; subjectColors.removeValue(forKey: old) }
        if manuallyAddedSubjects.contains(old) { manuallyAddedSubjects.remove(old); manuallyAddedSubjects.insert(new) }
        save()
    }
    func clearAll() {
        subjectColors = [:]; manuallyAddedSubjects = []
        UserDefaults.standard.removeObject(forKey: "subjectColors"); UserDefaults.standard.removeObject(forKey: "manualSubjects")
    }
    private func save() {
        if let encoded = try? JSONEncoder().encode(subjectColors) { UserDefaults.standard.set(encoded, forKey: "subjectColors") }
        if let encoded = try? JSONEncoder().encode(manuallyAddedSubjects) { UserDefaults.standard.set(encoded, forKey: "manualSubjects") }
    }
}

// MARK: - 3. 主视图
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HomeworkItem.endDate) private var allItems: [HomeworkItem]
    
    @StateObject private var subjectManager = SubjectManager()
    @State private var manager = HomeworkManager()
    
    @State private var selectedTab: String = "calendar"
    @State private var subjectFilter: String? = nil
    @State private var inputText: String = ""
    @State private var isProcessing: Bool = false
    @State private var statusMessage: String? = nil
    @State private var isError: Bool = false
    @State private var show401Alert: Bool = false
    
    @State private var showAPISheet: Bool = false
    @State private var showPrivacySheet: Bool = false
    @State private var editingItem: HomeworkItem? = nil
    @State private var showKeyMissingAlert: Bool = false
    @State private var showAddSubjectSheet: Bool = false
    @State private var showRenameSubjectSheet: Bool = false
    @State private var subjectToRename: String = ""
    @State private var showDeleteSubjectAlert: Bool = false
    @State private var subjectToDelete: String = ""
    @State private var showSubjectDeletedToast: Bool = false
    @State private var addSubjectSheetID = UUID()
    
    @AppStorage("appLanguage") private var appLang: AppLanguage = .chinese
    @AppStorage("outputLanguage") private var outputLang: OutputLanguage = .chinese
    @AppStorage("user_groq_api_key") private var userApiKey: String = ""
    @State private var developerMode: Bool = false
    @State private var logs: [AppLog] = []
    
    var isEnglish: Bool { appLang == .english }
    
    var allSubjects: [String] {
        let activeItems = allItems.filter { $0.deletedDate == nil }
        let dbSubjects = Set(activeItems.map { $0.subject })
        return Array(dbSubjects.union(subjectManager.manuallyAddedSubjects)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
    
    func cleanTrashOnStart() {
        let trashItems = allItems.filter { $0.deletedDate != nil }
        let now = Date()
        for item in trashItems {
            if let date = item.deletedDate, now.timeIntervalSince(date) > 7 * 24 * 3600 {
                modelContext.delete(item)
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            List {
                Section(header: Text(isEnglish ? "Views" : "视图")) {
                    SidebarRow(title: isEnglish ? "Calendar" : "作业日历", icon: "calendar", isSelected: selectedTab == "calendar") { selectedTab = "calendar"; subjectFilter = nil }
                    SidebarRow(title: isEnglish ? "Manage" : "作业管理", icon: "list.bullet.clipboard", isSelected: selectedTab == "manage") { selectedTab = "manage"; subjectFilter = nil }
                    SidebarRow(title: isEnglish ? "Recycle Bin" : "回收站", icon: "trash", isSelected: selectedTab == "trash") { selectedTab = "trash"; subjectFilter = nil }
                }
                
                Section(header: Text(isEnglish ? "Subjects" : "科目筛选")) {
                    ForEach(allSubjects, id: \.self) { subject in
                        SidebarRow(title: subject, icon: "tag.fill", color: subjectManager.getColor(for: subject), isSelected: subjectFilter == subject) {
                            subjectFilter = subject; selectedTab = "calendar"
                        }
                        .contextMenu {
                            Button(isEnglish ? "Rename" : "重命名") { subjectToRename = subject; showRenameSubjectSheet = true }
                            Divider()
                            Button(role: .destructive) { subjectToDelete = subject; showDeleteSubjectAlert = true } label: { Text(isEnglish ? "Delete Subject" : "删除学科") }
                        }
                    }
                    Button(action: { addSubjectSheetID = UUID(); showAddSubjectSheet = true }) {
                        HStack { Image(systemName: "plus.circle").frame(width: 20, alignment: .center).foregroundStyle(.secondary); Text(isEnglish ? "New Subject" : "新建学科").foregroundStyle(.secondary); Spacer() }.padding(.vertical, 4).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
                Section { SidebarRow(title: isEnglish ? "Settings" : "设置", icon: "gear", isSelected: selectedTab == "settings") { selectedTab = "settings" } }
            }
            .listStyle(.sidebar).navigationSplitViewColumnWidth(min: 220, ideal: 250)
        } detail: {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    if let filter = subjectFilter {
                        HStack {
                            Text(isEnglish ? "Filter: \(filter)" : "当前筛选: \(filter)").font(.headline)
                            Spacer()
                            Button(isEnglish ? "Clear" : "清除") { subjectFilter = nil; selectedTab = "calendar" }
                        }.padding().background(Color.yellow.opacity(0.1))
                    }
                    Group {
                        if selectedTab == "calendar" { CalendarListView(items: filteredItems, language: appLang, subjectManager: subjectManager, onEdit: { item in editingItem = item }) }
                        else if selectedTab == "manage" { TaskManagementView(items: allItems, isEnglish: isEnglish, language: appLang, allSubjects: allSubjects, onEdit: { item in editingItem = item }) }
                        else if selectedTab == "trash" { RecycleBinView(items: allItems, isEnglish: isEnglish, language: appLang, allSubjects: allSubjects) }
                        else if selectedTab == "settings" { SettingsView(appLang: $appLang, outputLang: $outputLang, developerMode: $developerMode, userApiKey: $userApiKey, subjectManager: subjectManager, showAPISheet: $showAPISheet, showPrivacySheet: $showPrivacySheet, allSubjects: allSubjects) }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    Spacer().frame(height: developerMode ? 200 : 80)
                }
                VStack(spacing: 0) {
                    if showSubjectDeletedToast { Text(isEnglish ? "Assignments moved to Trash" : "作业已移至回收站").font(.caption).foregroundStyle(.white).padding(8).background(Color.black.opacity(0.8)).cornerRadius(8).padding(.bottom, 4).transition(.move(edge: .top).combined(with: .opacity)) }
                    if let msg = statusMessage { Text(msg).font(.caption).foregroundStyle(isError ? .red : .green).padding(4).background(.thinMaterial).cornerRadius(4).padding(.bottom, 4) }
                    if selectedTab != "settings" { InputBar(text: $inputText, isProcessing: isProcessing, isEnglish: isEnglish, hasApiKey: !userApiKey.isEmpty, submitAction: sendMessage, onMissingKeyTap: { showKeyMissingAlert = true }).padding(.bottom, 10) }
                    if developerMode { DeveloperConsoleView(logs: logs, clearAction: { logs.removeAll() }).frame(height: 160).transition(.move(edge: .bottom)) }
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear { cleanTrashOnStart() }
        .alert(isEnglish ? "API Error" : "API 错误", isPresented: $show401Alert) { Button("OK", role: .cancel) { } } message: { Text("401 Unauthorized. Check your API Key.") }
        .alert(isEnglish ? "API Key Missing" : "未填写 API Key", isPresented: $showKeyMissingAlert) { Button(isEnglish ? "Enter Key" : "去填写") { showAPISheet = true }; Button(isEnglish ? "Cancel" : "取消", role: .cancel) { } } message: { Text(isEnglish ? "Do you want to open API settings?" : "是否跳转到 API 输入窗口？") }
        .alert(isEnglish ? "Delete Subject?" : "确认删除学科？", isPresented: $showDeleteSubjectAlert) { Button("Cancel", role: .cancel) { }; Button("Delete", role: .destructive) { performDeleteSubject(subjectToDelete) } } message: { Text(isEnglish ? "All assignments will be moved to Recycle Bin." : "确认后，该学科下的所有作业将被移至回收站。") }
        .sheet(isPresented: $showAPISheet) { APISettingsSheet(apiKey: $userApiKey, isEnglish: isEnglish) }
        .sheet(isPresented: $showPrivacySheet) { PrivacyView(isPresented: $showPrivacySheet, language: appLang) }
        .sheet(item: $editingItem) { item in EditHomeworkSheet(item: item, allSubjects: allSubjects, isEnglish: isEnglish) }
        .sheet(isPresented: $showAddSubjectSheet) { AddSubjectSheet(isEnglish: isEnglish) { en, zh in let f="\(zh) \(en)".trimmingCharacters(in:.whitespaces); if !f.isEmpty{subjectManager.addSubject(f)} }.id(addSubjectSheetID) }
        .sheet(isPresented: $showRenameSubjectSheet) { RenameSubjectSheet(oldName: subjectToRename, isEnglish: isEnglish) { en, zh in let f="\(zh) \(en)".trimmingCharacters(in:.whitespaces); if !f.isEmpty{performSubjectRename(from:subjectToRename,to:f)} } }
    }
    
    var filteredItems: [HomeworkItem] {
        let active = allItems.filter { $0.deletedDate == nil }
        if let filter = subjectFilter { return active.filter { $0.subject == filter } }
        return active
    }
    
    func performDeleteSubject(_ subject: String) {
        subjectManager.removeSubject(subject)
        let itemsToMove = allItems.filter { $0.subject == subject && $0.deletedDate == nil }
        for item in itemsToMove { item.deletedDate = Date() }
        if !itemsToMove.isEmpty { withAnimation { showSubjectDeletedToast = true }; DispatchQueue.main.asyncAfter(deadline: .now() + 3) { withAnimation { showSubjectDeletedToast = false } } }
        if subjectFilter == subject { subjectFilter = nil }
    }
    
    func performSubjectRename(from old: String, to new: String) {
        subjectManager.renameSubject(from: old, to: new)
        let itemsToUpdate = allItems.filter { $0.subject == old }
        for item in itemsToUpdate { item.subject = new }
        if subjectFilter == old { subjectFilter = new }
    }
    
    func sendMessage() {
        guard !inputText.isEmpty else { return }
        isProcessing = true; statusMessage = nil; logs.append(AppLog(type: .info, message: "UI: 用户发送"))
        Task {
            do {
                try await manager.processInput(text: inputText, outputLang: outputLang.displayName, modelContext: modelContext) { log in logs.append(log) }
                isError = false; statusMessage = isEnglish ? "Success!" : "发送成功！"; inputText = ""; try? await Task.sleep(nanoseconds: 3 * 1_000_000_000); statusMessage = nil
            } catch let error as HomeworkError {
                isError = true; statusMessage = "\(error.localizedDescription)"; logs.append(AppLog(type: .error, message: "\(error)"))
                if case .apiError(let code, _) = error, code == 401 { show401Alert = true }
            } catch { isError = true; statusMessage = "\(error.localizedDescription)" }
            isProcessing = false
        }
    }
}

// MARK: - 4. 关键组件：回收站与作业管理

struct RecycleBinView: View {
    @Environment(\.modelContext) private var modelContext
    var items: [HomeworkItem]
    var isEnglish: Bool
    var language: AppLanguage
    var allSubjects: [String]
    
    @State private var selectedItems = Set<HomeworkItem.ID>()
    @State private var showMoveSheet = false
    @State private var targetSubject = ""
    @State private var showEmptyTrashAlert = false
    
    var trashItems: [HomeworkItem] {
        items.filter { $0.deletedDate != nil }.sorted { ($0.deletedDate ?? Date()) > ($1.deletedDate ?? Date()) }
    }
    
    func formatDate(_ date: Date) -> String { let f=DateFormatter();f.locale=Locale(identifier:language.id);f.dateFormat=isEnglish ? "MMM d":"M月d日";return f.string(from:date) }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isEnglish ? "Recycle Bin (Auto-delete in 7 days)" : "回收站 (7天后自动删除)").font(.headline)
                Spacer()
                Button(isEnglish ? "Empty Trash" : "清空回收站") { showEmptyTrashAlert = true }.buttonStyle(.bordered).tint(.red).disabled(trashItems.isEmpty)
            }.padding().background(Color(nsColor: .controlBackgroundColor))
            
            if trashItems.isEmpty {
                Spacer(); Text(isEnglish ? "Trash is empty" : "回收站是空的").foregroundStyle(.secondary); Spacer()
            } else {
                List(selection: $selectedItems) {
                    ForEach(trashItems) { item in
                        HStack {
                            VStack(alignment: .leading) { Text(item.subject).font(.caption).bold(); Text(item.content) }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(formatDate(item.endDate)).font(.caption)
                                if let del = item.deletedDate { Text("Deleted: " + formatDate(del)).font(.caption2).foregroundStyle(.red) }
                            }
                        }.tag(item.id)
                    }
                }.listStyle(.inset)
            }
            
            if !selectedItems.isEmpty {
                HStack {
                    Text(isEnglish ? "\(selectedItems.count) Selected" : "已选 \(selectedItems.count) 项")
                    Spacer()
                    Button(isEnglish ? "Restore" : "复位") {
                        for id in selectedItems { if let item = items.first(where: {$0.id==id}) { item.deletedDate = nil } }
                        selectedItems.removeAll()
                    }
                    Button(isEnglish ? "Move to..." : "移动到...") {
                        if let firstId = selectedItems.first, let firstItem = items.first(where: {$0.id == firstId}) { targetSubject = firstItem.subject }
                        showMoveSheet = true
                    }
                    Button(isEnglish ? "Delete Permanently" : "彻底删除") {
                        for id in selectedItems { if let item = items.first(where: {$0.id==id}) { modelContext.delete(item) } }
                        selectedItems.removeAll()
                    }.tint(.red)
                }.padding().background(Material.bar)
            }
        }
        .sheet(isPresented: $showMoveSheet) {
            VStack(spacing: 20) {
                Text(isEnglish ? "Restore & Move to" : "恢复并移动到").font(.headline)
                Picker("", selection: $targetSubject) { ForEach(allSubjects, id: \.self) { Text($0).tag($0) } }.pickerStyle(.menu).labelsHidden()
                HStack {
                    Button(isEnglish ? "Cancel" : "取消") { showMoveSheet = false }
                    Button(isEnglish ? "Move" : "移动") {
                        for id in selectedItems {
                            if let item = items.first(where: {$0.id==id}) { item.subject = targetSubject; item.deletedDate = nil }
                        }
                        selectedItems.removeAll(); showMoveSheet = false
                    }.buttonStyle(.borderedProminent)
                }
            }.padding().frame(width: 300, height: 200)
        }
        .alert(isEnglish ? "Empty Trash?" : "清空回收站？", isPresented: $showEmptyTrashAlert) {
            Button("Cancel", role: .cancel) { }
            Button(isEnglish ? "Empty Trash" : "清空", role: .destructive) { for item in trashItems { modelContext.delete(item) } }
        } message: { Text(isEnglish ? "This action cannot be undone." : "此操作不可撤销，所有项目将永久删除。") }
    }
}

struct TaskManagementView: View {
    @Environment(\.modelContext) private var modelContext
    var items: [HomeworkItem]; var isEnglish: Bool; var language: AppLanguage
    var allSubjects: [String]
    var onEdit: (HomeworkItem) -> Void
    
    @State private var selectedDate: Date = Date(); @State private var filterByDate: Bool = false
    @State private var isSelectionMode: Bool = false
    @State private var selectedItems = Set<HomeworkItem.ID>()
    
    @State private var showMoveSheet = false
    @State private var targetSubject = ""
    
    var displayItems: [HomeworkItem] {
        let active = items.filter { $0.deletedDate == nil }.sorted { $0.creationDate > $1.creationDate }
        if filterByDate { return active.filter { Calendar.current.isDate($0.endDate, inSameDayAs: selectedDate) } }
        return active
    }
    
    func formatDate(_ date: Date) -> String { let f=DateFormatter();f.locale=Locale(identifier:language.id);f.dateFormat=isEnglish ? "MMM d":"M月d日";return f.string(from:date) }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Toggle(isOn: $filterByDate) { Text(isEnglish ? "Filter Date" : "按日期筛选") }.toggleStyle(.switch)
                if filterByDate { DatePicker("", selection: $selectedDate, displayedComponents: .date).labelsHidden() }
                Spacer()
                Toggle(isOn: $isSelectionMode) {
                    Image(systemName: "checkmark.circle").foregroundStyle(isSelectionMode ? .blue : .gray)
                    Text(isEnglish ? "Batch Select" : "批量选择")
                }.toggleStyle(.button).buttonStyle(.plain)
                Text("\(displayItems.count)").font(.caption).padding(.leading)
            }.padding().background(Color(nsColor: .controlBackgroundColor))
            
            List {
                ForEach(displayItems) { item in
                    HStack {
                        if isSelectionMode {
                            Image(systemName: selectedItems.contains(item.id) ? "checkmark.square.fill" : "square")
                                .foregroundStyle(selectedItems.contains(item.id) ? .blue : .gray)
                        }
                        VStack(alignment: .leading) {
                            Text(item.subject).font(.headline)
                            Text(item.content).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(formatDate(item.endDate)).font(.caption)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isSelectionMode {
                            if selectedItems.contains(item.id) { selectedItems.remove(item.id) }
                            else { selectedItems.insert(item.id) }
                        }
                    }
                    .contextMenu(isSelectionMode ? nil : ContextMenu(menuItems: {
                        Button(action: { onEdit(item) }) { Label(isEnglish ? "Edit" : "修改", systemImage: "pencil") }
                        Button(role: .destructive, action: { item.deletedDate = Date() }) { Label(isEnglish ? "Delete" : "删除", systemImage: "trash") }
                    }))
                }
            }
            .listStyle(.inset)
            
            if !selectedItems.isEmpty && isSelectionMode {
                HStack {
                    Text(isEnglish ? "\(selectedItems.count) Selected" : "已选 \(selectedItems.count) 项")
                    Spacer()
                    Button(isEnglish ? "Move to..." : "移动到...") {
                        if let firstId = selectedItems.first, let firstItem = items.first(where: {$0.id == firstId}) { targetSubject = firstItem.subject }
                        showMoveSheet = true
                    }
                    Button(isEnglish ? "Delete" : "删除") {
                        for id in selectedItems { if let item = items.first(where: {$0.id==id}) { item.deletedDate = Date() } }
                        selectedItems.removeAll()
                    }.tint(.red)
                }.padding().background(Material.bar)
            }
        }
        .onAppear{ filterByDate = false; isSelectionMode = false }
        .sheet(isPresented: $showMoveSheet) {
            VStack(spacing: 20) {
                Text(isEnglish ? "Move to Subject" : "移动到学科").font(.headline)
                Picker("", selection: $targetSubject) { ForEach(allSubjects, id: \.self) { Text($0).tag($0) } }.pickerStyle(.menu).labelsHidden()
                HStack {
                    Button(isEnglish ? "Cancel" : "取消") { showMoveSheet = false }
                    Button(isEnglish ? "Move" : "移动") {
                        for id in selectedItems { if let item = items.first(where: {$0.id==id}) { item.subject = targetSubject } }
                        selectedItems.removeAll(); isSelectionMode = false; showMoveSheet = false
                    }.buttonStyle(.borderedProminent)
                }
            }.padding().frame(width: 300, height: 200)
        }
    }
}

// MARK: - 5. 其他弹窗与子组件

struct AddSubjectSheet: View {
    var isEnglish: Bool; var onAdd: (String, String) -> Void; @Environment(\.dismiss) var dismiss; @State private var enName=""; @State private var zhName=""
    var body: some View { VStack(spacing:20){ Text(isEnglish ? "Add Subject":"新建学科").font(.headline); Form{
        HStack{Text(isEnglish ? "English (Max 75):":"英文名 (最多75):").frame(width:100,alignment:.leading);TextField(isEnglish ? "e.g. Math":"如 Math",text:$enName).onChange(of:enName){if enName.count>75{enName=String(enName.prefix(75))}}}
        HStack{Text(isEnglish ? "Chinese (Max 20):":"中文名 (最多20):").frame(width:100,alignment:.leading);TextField(isEnglish ? "e.g. 数学":"如 数学",text:$zhName).onChange(of:zhName){if zhName.count>20{zhName=String(zhName.prefix(20))}}}
    }; HStack{Button(isEnglish ? "Cancel":"取消"){dismiss()};Button(isEnglish ? "Add":"添加"){if !enName.isEmpty || !zhName.isEmpty{onAdd(enName,zhName);dismiss()}}.buttonStyle(.borderedProminent)} }.padding().frame(width:350,height:250).onAppear{enName="";zhName=""} }
}

struct RenameSubjectSheet: View {
    var oldName: String; var isEnglish: Bool; var onRename: (String, String) -> Void; @Environment(\.dismiss) var dismiss; @State private var enName=""; @State private var zhName=""
    var body: some View { VStack(spacing:20){ Text(isEnglish ? "Rename":"修改学科名").font(.headline); Text(oldName).font(.caption); Form{
        HStack{Text(isEnglish ? "English:":"英文名:").frame(width:70,alignment:.leading);TextField("En",text:$enName).onChange(of:enName){if enName.count>75{enName=String(enName.prefix(75))}}}
        HStack{Text(isEnglish ? "Chinese:":"中文名:").frame(width:70,alignment:.leading);TextField("Zh",text:$zhName).onChange(of:zhName){if zhName.count>20{zhName=String(zhName.prefix(20))}}}
    }; HStack{Button(isEnglish ? "Cancel":"取消"){dismiss()};Button(isEnglish ? "Save":"保存"){onRename(enName,zhName);dismiss()}.buttonStyle(.borderedProminent)} }.padding().frame(width:350,height:250).onAppear{
        let components = oldName.split(separator: " "); if components.count >= 2 { zhName = String(components.first!); enName = components.dropFirst().joined(separator: " ") } else { zhName = oldName }
    } }
}

struct EditHomeworkSheet: View {
    @Bindable var item: HomeworkItem; var allSubjects: [String]; var isEnglish: Bool; @Environment(\.dismiss) var dismiss
    var body: some View { Form{ Section(isEnglish ? "Edit":"修改"){ Picker(isEnglish ? "Subject":"科目", selection: $item.subject){ ForEach(allSubjects, id:\.self){ Text($0).tag($0) } }; TextEditor(text:$item.content).frame(height:100).onChange(of:item.content){if item.content.count>2000{item.content=String(item.content.prefix(2000))}}; TextField(isEnglish ? "Notes":"备注",text:Binding(get:{item.specialNotes ?? ""},set:{item.specialNotes=$0.isEmpty ? nil : $0})); DatePicker(isEnglish ? "Due":"截止",selection:$item.endDate) }; HStack{Spacer();Button(isEnglish ? "Save":"保存"){dismiss()}.buttonStyle(.borderedProminent)} }.padding().frame(width:400,height:450) }
}

struct APISettingsSheet: View {
    @Binding var apiKey: String; var isEnglish: Bool; @Environment(\.dismiss) var dismiss; @State private var showKey = false
    var body: some View { VStack(spacing:20){ Text("Groq API Key").font(.headline); VStack(alignment:.leading){ HStack{ if showKey{TextField("gsk_",text:$apiKey).textFieldStyle(.roundedBorder)}else{SecureField("gsk_",text:$apiKey).textFieldStyle(.roundedBorder)}; Button(action:{showKey.toggle()}){Image(systemName:showKey ? "eye.slash":"eye")}.buttonStyle(.plain) }; if !apiKey.isEmpty && !apiKey.hasPrefix("gsk_"){Text("Invalid").foregroundStyle(.red)} }.padding(); Button("Done"){dismiss()}.buttonStyle(.borderedProminent) }.frame(width:400,height:250) }
}

struct InputBar: View {
    @Binding var text: String; var isProcessing: Bool; var isEnglish: Bool; var hasApiKey: Bool; var submitAction: () -> Void; var onMissingKeyTap: () -> Void
    var body: some View { HStack(spacing: 12){ if hasApiKey{ TextField(isEnglish ? "Enter homework...":"输入作业...",text:$text).textFieldStyle(.plain).onSubmit{if !isProcessing{submitAction()}}.disabled(isProcessing); Button(action:submitAction){Image(systemName:"paperplane.circle.fill").font(.title2).foregroundStyle(.blue)}.buttonStyle(.plain).disabled(text.isEmpty||isProcessing) }else{ Button(action:onMissingKeyTap){HStack{Image(systemName:"exclamationmark.triangle.fill").foregroundStyle(.red);Text(isEnglish ? "API Key Missing (Click to set)":"未填写 API Key (点击跳转)").foregroundStyle(.red).font(.caption).underline();Spacer()}}.buttonStyle(.plain) } }.padding(12).background(Material.regular).cornerRadius(16).overlay(RoundedRectangle(cornerRadius:16).stroke(hasApiKey ? Color.gray.opacity(0.2):Color.red.opacity(0.5),lineWidth:1)).padding(.horizontal) }
}

struct DateHeader: View {
    let date: Date; let language: AppLanguage; var isToday: Bool { Calendar.current.isDateInToday(date) }
    var dateString: String { let f = DateFormatter(); f.locale = Locale(identifier: language.id); f.dateFormat = language == .english ? "MMM d, EEE" : "M月d日 EEEE"; return f.string(from: date) }
    var body: some View { HStack{Text(dateString).font(.headline).foregroundStyle(isToday ? .white:.primary).padding(.horizontal,12).padding(.vertical,6).background(isToday ? Color.blue:Color(nsColor:.windowBackgroundColor)).cornerRadius(8);Spacer()}.padding(.vertical,4).background(Color(nsColor:.windowBackgroundColor).opacity(0.9)) }
}

struct CalendarListView: View {
    var items: [HomeworkItem]; var language: AppLanguage; @ObservedObject var subjectManager: SubjectManager; var onEdit: (HomeworkItem) -> Void
    @State private var days: [Date] = (-30...30).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: Date()) }
    var body: some View { ScrollViewReader{proxy in ScrollView{ LazyVStack(spacing:15,pinnedViews:[.sectionHeaders]){ ForEach(days,id:\.self){day in let tasks=items.filter{isTaskActive(task:$0,on:day)}.sorted{if $0.isCompleted != $1.isCompleted{return !$0.isCompleted};return $0.subject<$1.subject}; if !tasks.isEmpty || Calendar.current.isDateInToday(day){ Section(header:DateHeader(date:day,language:language)){ VStack(spacing:5){ if tasks.isEmpty{Text(language == .english ? "No Homework":"无作业").font(.caption).foregroundStyle(.secondary).padding(.vertical,10).frame(maxWidth:.infinity).background(Color.gray.opacity(0.05)).cornerRadius(8)}else{ForEach(tasks){task in HomeworkRowCard(task:task,subjectManager:subjectManager,onEdit:onEdit)}} } }.id(day) } } }.padding() }.onAppear{if let t=days.first(where:{Calendar.current.isDateInToday($0)}){proxy.scrollTo(t,anchor:.top)}} } }
    func isTaskActive(task: HomeworkItem, on date: Date) -> Bool { let c = Calendar.current; if c.isDate(task.endDate, inSameDayAs: date) { return true }; return date >= c.startOfDay(for: task.startDate) && date <= task.endDate }
}

struct HomeworkRowCard: View {
    @Bindable var task: HomeworkItem; @ObservedObject var subjectManager: SubjectManager; var onEdit: (HomeworkItem) -> Void
    var body: some View { HStack{ Button(action:{withAnimation{task.isCompleted.toggle()}}){Image(systemName:task.isCompleted ? "checkmark.square.fill":"square").font(.title2).foregroundStyle(task.isCompleted ? .gray:.blue)}.buttonStyle(.plain); Rectangle().fill(task.isCompleted ? .gray:subjectManager.getColor(for:task.subject)).frame(width:4); VStack(alignment:.leading){ HStack{ Text(task.subject).font(.caption).bold().padding(2).background(task.isCompleted ? Color.gray.opacity(0.1):subjectManager.getColor(for:task.subject).opacity(0.1)).cornerRadius(4).foregroundStyle(task.isCompleted ? .gray:.primary); if let notes=task.specialNotes{Text(notes).font(.caption2).foregroundStyle(task.isCompleted ? .gray:.red).padding(2).overlay(RoundedRectangle(cornerRadius:4).stroke(task.isCompleted ? Color.gray:Color.red,lineWidth:1))} }; Text(task.content).font(.body).strikethrough(task.isCompleted).foregroundStyle(task.isCompleted ? .gray:.primary) }.padding(.vertical,8); Spacer() }.padding(.horizontal,8).background(Color(nsColor:.controlBackgroundColor)).cornerRadius(8).overlay(RoundedRectangle(cornerRadius:8).stroke(Color.gray.opacity(0.1))).opacity(task.isCompleted ? 0.6:1.0)
        // ✨ 新增：作业日历右键菜单
        .contextMenu {
            Button(action: { onEdit(task) }) { Label("Edit / 修改", systemImage: "pencil") }
            Button(role: .destructive, action: { task.deletedDate = Date() }) { Label("Delete / 删除", systemImage: "trash") }
        }
    }
}

struct SidebarRow: View {
    let title: String; let icon: String; var color: Color = .primary; let isSelected: Bool; let action: () -> Void
    var body: some View { HStack{Image(systemName:icon).foregroundStyle(color).frame(width:20,alignment:.center);Text(title);Spacer()}.padding(.vertical,4).contentShape(Rectangle()).onTapGesture{action()}.listRowBackground(isSelected ? Color.blue.opacity(0.1):Color.clear) }
}

struct DeveloperConsoleView: View {
    var logs: [AppLog]; var clearAction: () -> Void
    func copyLogs() { let text=logs.map{"[\($0.type)] \($0.message)"}.joined(separator:"\n"); NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text,forType:.string) }
    var body: some View { VStack{HStack{Text("Console");Spacer();Button("Copy"){copyLogs()};Button("Clear"){clearAction()}}.padding(5).background(Color.black);ScrollView{VStack(alignment:.leading){ForEach(logs){log in Text(log.message).font(.caption).foregroundStyle(.green)}}}}.background(Color.black) }
}

struct SettingsView: View {
    @Binding var appLang: AppLanguage; @Binding var outputLang: OutputLanguage; @Binding var developerMode: Bool; @Binding var userApiKey: String
    @ObservedObject var subjectManager: SubjectManager
    @Binding var showAPISheet: Bool; @Binding var showPrivacySheet: Bool
    var allSubjects: [String]
    @Environment(\.modelContext) private var modelContext
    var isEnglish: Bool { appLang == .english }
    @State private var showResetSheet = false; @State private var showMathSheet = false; @State private var showWrongAlert = false; @State private var pendingAction: ClearActionType? = nil; @State private var num1=0; @State private var num2=0; @State private var ans=""
    var body: some View { Form{ Section{VStack(spacing:10){Text("📁").font(.system(size:60));Text("作业助手 Homework Assistant").font(.largeTitle).bold();Text("Made by Hector").font(.body).foregroundStyle(.primary);Text("ver 26.2").font(.caption).foregroundStyle(.secondary)}.frame(maxWidth:.infinity).padding(.vertical,10)}; Section(header:Label(isEnglish ? "Preferences":"偏好设置",systemImage:"gearshape")){Picker(isEnglish ? "App Language":"软件语言",selection:$appLang){ForEach(AppLanguage.allCases){Text($0.displayName).tag($0)}};Picker(isEnglish ? "Output Language":"输出语言",selection:$outputLang){ForEach(OutputLanguage.allCases){Text($0.displayName).tag($0)}};Toggle(isEnglish ? "Developer Mode":"开发者模式",isOn:$developerMode)}; Section(header:Label(isEnglish ? "Subject Colors":"学科颜色管理",systemImage:"paintpalette")){if allSubjects.isEmpty{Text("No subjects").foregroundStyle(.secondary)};ForEach(allSubjects,id:\.self){sub in HStack{Text(sub);Spacer();ColorPicker("",selection:Binding(get:{subjectManager.getColor(for:sub)},set:{subjectManager.setColor(for:sub,color:$0)}))}}}; Section(header:Label("API",systemImage:"network")){Button(isEnglish ? "Configure API Key...":"配置 API Key..."){showAPISheet=true};if !userApiKey.isEmpty{Text("Status: Key Loaded").font(.caption).foregroundStyle(.green)}}; Section(header:Label(isEnglish ? "Reset":"重置",systemImage:"trash")){Button(isEnglish ? "Reset Options...":"重置选项..."){showResetSheet=true}.foregroundStyle(.red).confirmationDialog("Reset",isPresented:$showResetSheet){Button("Clear API Key Only"){userApiKey=""};Button("Clear All Data"){pendingAction = .dataOnly;showMathSheet=true};Button("Factory Reset",role:.destructive){pendingAction = .both;showMathSheet=true};Button("Cancel",role:.cancel){}}}; Section{Button(action:{showPrivacySheet=true}){Label(isEnglish ? "Privacy Policy":"隐私政策与用户协议",systemImage:"hand.raised")}} }.formStyle(.grouped).padding().sheet(isPresented:$showMathSheet){VStack(spacing:20){Text("Security Check").font(.headline);Text("\(num1) + \(num2) = ?").font(.title);TextField("0-999",text:$ans).textFieldStyle(.roundedBorder).frame(width:80).multilineTextAlignment(.center).onChange(of:ans){let f=ans.filter{"0123456789".contains($0)};if f.count>3{ans=String(f.prefix(3))}else{ans=f}}.onSubmit{performClear()};HStack{Button("Cancel"){showMathSheet=false};Button("Confirm"){performClear()}.buttonStyle(.borderedProminent).tint(.red)}}.padding().frame(width:300,height:250).onAppear{generateMath()}.alert(isEnglish ? "Error":"输入错误",isPresented:$showWrongAlert){Button("OK",role:.cancel){}}message:{Text(isEnglish ? "Incorrect.":"答案错误，已刷新。")}} }
    func generateMath(){num1=Int.random(in:10...50);num2=Int.random(in:10...50);ans=""}
    func performClear(){if Int(ans)==(num1+num2){if pendingAction == .dataOnly || pendingAction == .both{try? modelContext.delete(model:HomeworkItem.self)};if pendingAction == .both{userApiKey="";subjectManager.clearAll()};showMathSheet=false}else{showWrongAlert=true;generateMath()}}
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
    func toHex() -> String? {
        guard let components = NSColor(self).cgColor.components, components.count >= 3 else { return nil }
        let r = Float(components[0]); let g = Float(components[1]); let b = Float(components[2])
        return String(format: "%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}
