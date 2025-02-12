//
//  ContentView.swift
//  LanguageTool
//
//  Created by 华子 on 2025/2/12.
//

import SwiftUI
import SwiftData
import AppKit

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
                        Button(action: openJSONFolder) {
                            Label("Open JSON Folder", systemImage: "folder")
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
        
        // 创建日期格式器
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let fileName = "\(dateFormatter.string(from: Date())).json"
        
        if let jsonData = LocalizationJSONGenerator.generateJSON(for: keys) {
            LocalizationJSONGenerator.saveJSONToFile(data: jsonData, fileName: fileName)
        }
        //选择保存目录的方式
//        let keys = ["首页", "高级功能已解锁！", "设置", "关于我们"]
//
//        if let jsonData = LocalizationJSONGenerator.generateJSON(for: keys) {
//            LocalizationJSONGenerator.saveJSONToFile(data: jsonData) // 调用新的保存方法
//        }
        
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

    private func openJSONFolder() {
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: documentsPath.path)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
