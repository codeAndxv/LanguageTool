import Foundation
import SwiftUI

struct DeepseekDemo: View {
    @State private var messages: [Message] = []
    @State private var inputText: String = ""
    @State private var responseMessage: String = ""
    @State private var isLoading: Bool = false
    
    func sendMessage() {
        isLoading = true
        messages.append(Message(role: "system", content: inputText))
        
        AIService.shared.sendMessage(messages: messages) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let response):
                    responseMessage = response
                    messages.append(Message(role: "assistant", content: response))
                case .failure(let error):
                    responseMessage = error.localizedDescription
                }
            }
        }
    }
    
    var body: some View {
        VStack {
            TextField("输入消息", text: $inputText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            Button("发送") {
                sendMessage()
            }
            
            NavigationLink {
                Transfer()
            } label: {
                Text("读取")
            }

            if isLoading {
                ProgressView()
            }
        }
    }
}
