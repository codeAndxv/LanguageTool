# Language Tool

Language Tool 是一个 macOS 应用程序，用于自动化生成 Xcode 项目的多语言本地化文件。它可以直接读取和生成 Xcode 的 `.xcstrings` 文件，并通过 AI 翻译服务自动翻译成多种语言。

## 功能特点

- 📖 支持读取Localizable.xcstrings 或 Localizable.strings 和 JSON文件
- 🌍 支持 50+ 种语言的自动翻译
- 🔄 批量翻译处理
- 💾 生成标准的 Xcode `.xcstrings`或`.strings` 格式
- ⚡️ 简单直观的用户界面
- 🎯 完全适配 Xcode 本地化工作流

## 支持的语言

包括但不限于：
- 中文（简体、繁体、香港繁体）
- 英语（美国、英国、澳大利亚等变体）
- 日语
- 韩语
- 欧洲语言（法语、德语、西班牙语等）
- 东南亚语言（泰语、越南语等）
- 中东语言（阿拉伯语等）

## 使用方法

1. 启动应用程序![](https://raw.githubusercontent.com/aSynch1889/image/master/uPic/2pmTBE20250213230424.png)
2. 在设置中配置 AI 服务的 API Key
   ![](https://raw.githubusercontent.com/aSynch1889/image/master/uPic/xTfNrr20250224113359.png)
3. 选择源文件（Localizable.xcstrings 或 Localizable.strings 文件）
4. 选择目标语言
5. 选择保存位置
6. 点击"开始转换"
7. 等待转换完成
8. 将生成的 `.xcstrings`或`.strings` 文件添加到你的 Xcode 项目中

## 系统要求

- macOS 13.0 或更高版本
- Xcode 15.0 或更高版本（用于 .xcstrings 支持）

## 安装

由于这是一个开源项目，目前没有经过 Apple 公证，安装时需要一些额外步骤：

1. 从 Releases 页面下载最新的 .zip 文件
2. 解压缩文件
3. 将 .app 文件拖入 Applications 文件夹
4. 首次运行时：
   - 右键点击应用图标
   - 选择"打开"
   - 在弹出的警告对话框中选择"打开"
   

注意：由于应用没有经过 Apple 签名，首次运行时系统会显示安全警告，这是正常的。如果你担心安全问题，可以查看源代码并自行编译。

### 从源码构建

如果你更倾向于自己构建应用：

1. 克隆仓库：
   ```bash
   git clone https://github.com/aSynch1889/LanguageTool.git
   ```
2. 使用 Xcode 打开项目
3. 选择 Product > Build
4. 构建完成后，应用会出现在 Xcode 的产品文件夹中

## 开发环境

- Swift 5.9
- SwiftUI
- Xcode 15.0+

## 注意事项

- 使用前需要配置有效的 DeepSeek AI 或者 Gemini 服务 API Key
- 建议在使用前备份原有的本地化文件
- 翻译结果可能需要人工审核以确保准确性

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

本项目采用 MIT 许可证。详见 [LICENSE](LICENSE) 文件。

## 致谢

- DeepSeek AI、Gemini 提供翻译服务
- SwiftUI 框架
- 所有贡献者和用户

## 联系方式

如有问题或建议，请通过 GitHub Issues 与我们联系。

---

Made with ❤️ by [华子]
