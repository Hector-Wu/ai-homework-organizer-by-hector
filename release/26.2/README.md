# Homework Assistant (作业助手)

![License](https://img.shields.io/badge/license-AGPL--3.0-blue.svg)
![Platform](https://img.shields.io/badge/platform-macOS-lightgrey.svg)
![Swift](https://img.shields.io/badge/SwiftUI-SwiftData-orange.svg)

Homework Assistant is a native macOS desktop application designed to process unstructured, natural language homework descriptions into structured scheduling data. It leverages external Large Language Models (LLMs) to perform entity extraction (subject, content, deadline) and utilizes SwiftData for local persistence.

> **Disclaimer:** This project contains code structured and generated with the assistance of AI tools. All logic, architecture, and code have been reviewed and tested by the author.

---

## ⚙️ System Requirements
*   **OS:** macOS 14.0 or later
*   **IDE:** Xcode 15.0 or later
*   **Language:** Swift 5.9+

## 🔑 API Configuration (Bring Your Own Key)

This application operates purely locally and **does not** include any pre-configured API keys or backend servers. Users must supply their own API keys from supported providers to utilize the parsing features.

Supported LLM Providers:
1.  **Groq:** Recommended for lower latency. Target model: `llama-3.3-70b-versatile`. [Get Key](https://console.groq.com/keys)
2.  **Google AI Studio:** Target model series: `gemma-3`. [Get Key](https://aistudio.google.com/app/apikey)

*API keys are stored securely in local `UserDefaults`. No data is transmitted to third parties other than the direct API calls to the chosen provider.*

---

## 🇬🇧 English Documentation

### Technical Highlights in v26.2

*   **Dual LLM Engine Implementation:** Abstracted network layer supporting both Groq (OpenAI-compatible endpoints) and Google Gemini REST APIs.
*   **Asynchronous Model Downgrade Mechanism:** Implemented a robust fallback strategy for Gemma 3. If a high-parameter model (e.g., `27B`) encounters a non-auth error (such as HTTP 429 Quota Exceeded), the network task is suspended using `CheckedContinuation`. A UI prompt requests user authorization before falling back to lower-parameter models (`4B` or `1B`), mitigating the risk of silent parsing degradation.
*   **Soft Deletion & Data Lifecycle:** Assignments are not deleted immediately. A `deletedDate` property marks items for the Recycle Bin. A startup task automatically purges records residing in the bin for more than 7 days.
*   **Customizable Prompt Engineering:** Developers can modify the System Prompt via the UI. The application dynamically injects contextual variables (e.g., `{{LANG}}`, `{{DATE}}` with weekdays) to improve the LLM's relative time calculation accuracy (e.g., "next Monday").

### Core Features
*   **Natural Language Parsing:** Converts raw text into JSON structures defining subjects, tasks, and relative due dates.
*   **Bilingual Interface & Subject Handling:** Supports English and Simplified Chinese. The AI automatically categorizes subjects into bilingual tags (e.g., "Math 数学") and normalizes similar subject names using localized string comparison.
*   **Calendar View:** A chronological timeline displaying active assignments, colored subject tags, and completion toggles.
*   **Data Management:** Batch operations (move, delete) in the Manage tab, paired with a hierarchical settings interface utilizing `confirmationDialog` to prevent accidental data wipes.

---

## 🇨🇳 中文文档

### 项目简介
作业助手 (Homework Assistant) 是一款基于 SwiftUI 构建的 macOS 原生应用程序。其核心目的是利用大语言模型 (LLM)，将用户输入的非结构化自然语言作业文本，解析并提取为结构化的数据库条目（包含学科、作业内容、截止日期及备注），从而实现自动化的日程管理。

### v26.2 技术细节与更新

*   **多模型引擎架构**: 网络层通过协议抽象，同时支持 Groq (Llama 3.3) 与 Google (Gemma 3) 接口。
*   **基于 Continuation 的异步降级熔断**: 针对 Gemma 3 实现了交互式的失败回退（Fallback）机制。当高精度模型（如 `27B`）触发限流（HTTP 429）或服务器无响应时，系统底层会利用 Swift 的 `CheckedContinuation` 挂起异步网络任务，向主线程抛出 UI 弹窗警告。用户确认后，程序才会在原上下文中恢复执行并请求低参数模型（`4B` / `1B`）。此机制避免了静默降级导致的解析准确度下降问题。
*   **软删除与生命周期管理**: 数据库层面引入 `deletedDate` 字段实现“软删除”（即回收站功能）。应用在 `onAppear` 生命周期中会执行自动清理任务，物理删除处于回收站超过 7 天的数据。
*   **动态提示词注入 (Prompt Engineering)**: 开放了 System Prompt 的自定义接口。在每次请求前，系统会在运行时动态替换 `{{LANG}}`（目标输出语言）与 `{{DATE}}`（包含当前星期几的日期字符串），以显著提高 LLM 对“下周一”、“明天”等相对时间概念的推理准确率。
*   **状态隔离的设置视图**: 重构了偏好设置页面，针对“清空数据”和“清除 API 密钥”等危险操作引入了多级 `confirmationDialog` 确认机制。

### 核心工作流
1.  **输入与拦截**: 接收用户文本，校验本地是否已配置对应的 API Key。
2.  **网络通讯**: 附带定制化 Prompt 请求 LLM，约束模型输出严格的 JSON 数组格式。
3.  **解析与容错**: 去除 LLM 可能返回的 Markdown 标记 (如 ````json`)，通过 `JSONDecoder` 映射为本地结构体。
4.  **智能归一化**: 将解析出的学科名（中英双语）与数据库已有学科进行分词比对，若存在高相似度则自动归类，防止产生冗余学科标签。
5.  **相对时间推算**: 根据 JSON 返回的 `daysFromToday`、`durationDays` 等相对数值，通过 `Calendar` API 精确计算绝对 `Date` 并在 SwiftData 容器中落库。

### 编译与运行
1.  将本仓库克隆至本地。
2.  使用 Xcode (15.0 或更高版本) 打开 `HomeworkAssistant.xcodeproj`。
3.  等待 Swift Package 依赖解析完成。
4.  按下 `Cmd + R` 编译并在 macOS 环境下运行。

---

**Author:** Hector Wu
**Version:** 26.2
**License:** AGPL-3.0