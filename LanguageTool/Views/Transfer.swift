import SwiftUI

struct Transfer: View {
    var body: some View {
        VStack {
            Text("选择读取路径")
            Text("选择保存路径")
            
            Button("发送") {
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                panel.canChooseFiles = true
                panel.allowedContentTypes = [.json]
                
                panel.begin { response in
                    if response == .OK, let fileURL = panel.url {
                        let outputFile = "chinese_keys.txt"
                        JsonUtils.extractChineseKeys(from: fileURL.path, to: outputFile)
                    }
                }
            }
        }
    }
}
