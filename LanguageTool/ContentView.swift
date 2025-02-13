import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Language Tool")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(
                Divider(),
                alignment: .bottom
            )
            
            // 主要内容
            TransferView()
                .frame(minWidth: 600, minHeight: 500)
                .padding()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [], inMemory: true)
}
