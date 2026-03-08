// Filename: PrivacyView.swift
// 用途：展示隐私政策与免责声明 (完整专业版)

import SwiftUI

struct PrivacyView: View {
    @Binding var isPresented: Bool
    var language: AppLanguage
    
    var isEnglish: Bool { language == .english }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部导航栏
            HStack {
                Text(isEnglish ? "Privacy Policy & User Agreement" : "隐私政策与用户协议")
                    .font(.title2)
                    .bold()
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.gray)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // 滚动协议内容
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // 引言
                    Text(isEnglish ?
                         "Welcome to Homework Assistant. By using this application, you acknowledge and agree to the following terms. We take your privacy very seriously." :
                         "欢迎使用作业助手 (Homework Assistant)。使用本应用程序即表示您知悉并同意以下条款。我们非常重视您的隐私与数据安全。")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    
                    // 第一条：本地存储
                    VStack(alignment: .leading, spacing: 8) {
                        Text(isEnglish ? "1. 100% Local Data Storage" : "1. 100% 本地数据存储")
                            .font(.headline)
                        Text(isEnglish ?
                             "All your data, including homework assignments, subject configurations, and app preferences, are stored exclusively on your current device using Apple's SwiftData technology. The developer does not collect, track, or upload ANY of your personal schedule data to any cloud servers." :
                             "您的所有数据（包括作业日程、学科配置以及应用的偏好设置）均利用苹果的 SwiftData 技术完全、独占地保存在您的当前设备上。开发者绝对不会收集、追踪或将您的任何个人日程数据上传至任何云端服务器。")
                            .font(.body)
                    }
                    
                    // 第二条：网络请求与 AI 隐私
                    VStack(alignment: .leading, spacing: 8) {
                        Text(isEnglish ? "2. Third-Party AI Services & Network" : "2. 第三方 AI 服务与网络请求")
                            .font(.headline)
                        Text(isEnglish ?
                             "To intelligently parse your assignments, the natural language text you enter into the input bar is sent directly to your chosen AI provider (Groq or Google Gemma 3). We do not intercept or store this communication. Your privacy regarding the parsed text is governed by the respective privacy policies of Groq Inc. and Google LLC." :
                             "为了智能解析您的作业，您在输入框中填写的自然语言文本将直接发送给您选择的 AI 服务提供商（Groq 或 Google Gemma 3）。我们不会拦截或存储这些通讯。您发送的文本隐私受 Groq Inc. 与 Google LLC 各自的隐私政策约束。")
                            .font(.body)
                    }
                    
                    // 第三条：API 密钥保护
                    VStack(alignment: .leading, spacing: 8) {
                        Text(isEnglish ? "3. API Key Security (BYOK)" : "3. API 密钥安全 (BYOK)")
                            .font(.headline)
                        Text(isEnglish ?
                             "This app operates on a 'Bring Your Own Key' model. Your API keys are saved locally in the device's preferences. The developer has absolutely no access to your keys and is not responsible for any quota usage, rate limits, or billing issues incurred on your personal AI provider accounts." :
                             "本应用采用“自带密钥 (BYOK)”模式运行。您的 API 密钥仅保存在设备的本地偏好设置中。开发者完全无法获取您的密钥，也不对您在个人 AI 服务商账户中产生的任何配额消耗、频率限制或计费问题负责。")
                            .font(.body)
                    }
                    
                    // 第四条：准确性与免责声明
                    VStack(alignment: .leading, spacing: 8) {
                        Text(isEnglish ? "4. Accuracy & Disclaimer (Important)" : "4. 准确性与免责声明 (重要)")
                            .font(.headline)
                            .foregroundStyle(.red)
                        Text(isEnglish ?
                             "This tool relies on Large Language Models (LLMs) which can occasionally hallucinate, make logical errors, or misinterpret deadlines. **You are solely responsible for verifying the extracted tasks against your actual assignments.** The developer assumes no liability for missed deadlines, academic penalties, or other consequences arising from reliance on this app." :
                             "本工具高度依赖大语言模型 (LLM)，而这些模型偶尔可能会产生“幻觉”、逻辑错误或误解截止日期。**您有责任自行核对提取的作业任务是否与实际布置相符。** 开发者不对因依赖本应用而导致的任何漏交作业、学业惩罚或其他后果承担任何法律责任。")
                            .font(.body)
                    }
                    
                    // 第五条：高级设置
                    VStack(alignment: .leading, spacing: 8) {
                        Text(isEnglish ? "5. Developer Mode & Advanced Tweaks" : "5. 开发者模式与高级调整")
                            .font(.headline)
                        Text(isEnglish ?
                             "If you choose to enable Developer Mode and modify the System Prompt, you are directly altering the AI's behavior instructions. You are fully responsible for any crashes, infinite loops, or JSON parsing failures caused by unsupported prompt formatting." :
                             "如果您选择开启开发者模式并修改系统提示词 (System Prompt)，您正在直接更改 AI 的行为指令。您需对因不支持的提示词格式所导致的解析崩溃、无限循环或 JSON 提取失败负全责。")
                            .font(.body)
                    }
                    
                    Spacer(minLength: 20)
                    
                    // 底部版权
                    HStack {
                        Spacer()
                        Text("© 2026 Hector Wu. All Rights Reserved.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    
                }
                .padding(24)
            }
        }
        .frame(width: 550, height: 650) // 略微放大窗口以容纳更多文字
    }
}
