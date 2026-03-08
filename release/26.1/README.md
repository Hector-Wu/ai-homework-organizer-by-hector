# Homework Assistant (作业助手)

![License](https://img.shields.io/badge/license-AGPL--3.0-blue.svg)
![Platform](https://img.shields.io/badge/platform-macOS-lightgrey.svg)
![Swift](https://img.shields.io/badge/SwiftUI-SwiftData-orange.svg)

**Homework Assistant** is a smart, native macOS application designed to help students organize their school assignments efficiently. It utilizes AI to parse natural language input into structured schedules.

> **Note:** This project contains code generated with the assistance of AI tools (Gemini). All code has been reviewed and adapted by the author.

---

## 🇬🇧 English

### Why Groq API Only?
Currently, this application **exclusively supports the Groq API**.
Due to the author's current development resources and capabilities, Groq was selected as the sole backend because of its exceptional inference speed and its generous **free tier** for developers. Support for other LLM providers (like OpenAI or Gemini) is not planned for the immediate future.

### Features
*   **🤖 AI-Powered Parsing**: Simply type or paste your homework (e.g., "Math workbook p5 due Thursday"), and the app understands the subject, content, and due date.
*   **🇨🇳/🇬🇧 Bilingual Support**: Full support for both English and Chinese interfaces. Subjects are managed in a bilingual format (e.g., "Math 数学").
*   **📅 Smart Calendar**: View assignments in a timeline. Mark them as done with a satisfying checkbox.
*   **🎨 Customization**: Customize subject colors. Auto-assigns distinct colors to new subjects.
*   **🗑️ Recycle Bin**: Safely delete assignments with a "Soft Delete" feature. Items in the trash are permanently deleted after 7 days.
*   **🔒 Privacy Focused**: All data is stored locally on your Mac using SwiftData. Your API Key is stored in your local settings and interacts directly with Groq servers.

### Requirements
*   macOS 15.4 or later
*   Xcode 15+ (to build from source)
*   A valid [Groq API Key](https://console.groq.com/keys)

### How to Build & Run
1.  Clone this repository.
2.  Open `HomeworkAssistant.xcodeproj` in Xcode.
3.  Ensure your signing team is configured in project settings.
4.  Build and Run (Cmd + R).

### License
This project is licensed under the **AGPL-3.0 License**. See the [LICENSE](LICENSE) file for details.

---

## 🇨🇳 中文

### 为什么仅支持 Groq API？
目前本软件**仅支持 Groq API**。
受限于作者目前的开发精力与资源（且考虑到 Groq 提供了极快且**免费**的 API 调用额度），目前将其作为唯一的 AI 推理后端。暂无计划在短期内适配 OpenAI 或其他付费模型接口。

### 主要功能
*   **🤖 智能识别**: 支持自然语言输入（例如：“物理卷子一张周四交”），AI 自动提取科目、内容和截止日期。
*   **🇨🇳/🇬🇧 双语支持**: 界面支持中英切换，学科名采用双语格式（如 “Physics 物理”）管理。
*   **📅 作业日历**: 清晰的列表视图，支持打钩完成、划掉作业。
*   **🎨 个性化**: 支持自定义学科颜色，新学科自动分配不重复的颜色。
*   **🗑️ 回收站机制**: 防止误删作业。删除的作业会进入回收站，支持恢复或7天后自动清除。
*   **🔒 隐私安全**: 所有作业数据通过 SwiftData 存储在您的本地设备上。API Key 仅保存在本地设置中，直接与 Groq 服务器通信。

### 系统要求
*   macOS 15.4 或更高版本
*   Xcode 15+ (用于编译源码)
*   有效的 [Groq API Key](https://console.groq.com/keys)

### 如何安装与运行
1.  克隆（Clone）本仓库到本地。
2.  使用 Xcode 打开 `HomeworkAssistant.xcodeproj`。
3.  在项目设置中配置您的签名团队（Signing Team）。
4.  点击运行 (Cmd + R)。

### 开源协议
本项目采用 **AGPL-3.0 许可证**。详情请参阅 [LICENSE](LICENSE) 文件。

---

**Made by Hector**
*ver 26.2*
