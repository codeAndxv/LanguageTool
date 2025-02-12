//
//  ContentView.swift
//  LanguageTool
//
//  Created by 华子 on 2025/2/12.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(items) { item in
                    NavigationLink {
                        Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
                    } label: {
                        Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .toolbar {
                ToolbarItem {
                    HStack {
                        Button(action: addItem) {
                            Label("Add Item", systemImage: "plus")
                        }
                        NavigationLink {
                            DeepseekDemo()
                        } label: {
                            Text("add")
                        }

                    }
                }
            }
        } detail: {
            Text("Select an item")
        }
    }

    private func addItem() {
        let keys = ["首页", "高级功能已解锁！", "设置", "关于我们"]
        let filePath = "/Users/huazi/Documents/file.json"

        if let jsonData = LocalizationJSONGenerator.generateJSON(for: keys) {
            LocalizationJSONGenerator.saveJSONToFile(data: jsonData, filePath: filePath)
        }
        
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
