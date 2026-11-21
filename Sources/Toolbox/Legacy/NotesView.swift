import SwiftUI

struct Note: Identifiable, Codable, Equatable {
    var id = UUID()
    var text = ""
    var updatedAt = Date()
}

final class NoteStore: ObservableObject {
    @Published var notes: [Note] = [] { didSet { save() } }

    private var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("notes.json")
    }

    init() { load() }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Note].self, from: data) else { return }
        notes = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func addNote() {
        notes.insert(Note(text: ""), at: 0)
    }

    func delete(at offsets: IndexSet) {
        notes.remove(atOffsets: offsets)
    }
}

struct NotesView: View {
    @StateObject private var store = NoteStore()

    static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy/M/d HH:mm"
        return df
    }()

    var body: some View {
        Group {
            if store.notes.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "note.text")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary)
                    Text("メモがありません")
                        .foregroundColor(.secondary)
                    Text("右上の + で追加できます")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach($store.notes) { $note in
                        NavigationLink {
                            NoteEditorView(note: $note)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(note.text.split(separator: "\n").first.map(String.init) ?? "無題")
                                    .lineLimit(1)
                                Text(Self.dateFormatter.string(from: note.updatedAt))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: store.delete)
                }
                .listStyle(.insetGrouped)
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 72)
                }
            }
        }
        .navigationTitle("メモ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    store.addNote()
                    haptic(.light)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

struct NoteEditorView: View {
    @Binding var note: Note

    var body: some View {
        TextEditor(text: $note.text)
            .padding(8)
            .navigationTitle("メモ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        UIPasteboard.general.string = note.text
                        haptic(.light)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .disabled(note.text.isEmpty)
                }
            }
            .onChange(of: note.text) { _ in
                note.updatedAt = Date()
            }
    }
}
