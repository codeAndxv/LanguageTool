import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TransferView()
            .frame(minWidth: 600, minHeight: 500)
            .padding()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
