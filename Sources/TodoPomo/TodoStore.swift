import Foundation

struct TodoItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var done = false
    var pomodoros = 0
}

/// Penyimpanan sederhana: daftar tugas di-encode ke JSON dan disimpan di UserDefaults.
final class TodoStore: ObservableObject {
    @Published var items: [TodoItem] = []
    @Published var focusID: UUID?

    private let key = "todo.items.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([TodoItem].self, from: data) {
            items = saved
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func add(_ title: String) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        items.append(TodoItem(title: t))
        save()
    }

    func toggle(_ id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].done.toggle()
        if items[i].done && focusID == id { focusID = nil }
        save()
    }

    @discardableResult
    func move(_ id: UUID, toPositionOf targetID: UUID) -> Bool {
        guard id != targetID,
              let source = items.firstIndex(where: { $0.id == id && !$0.done }),
              let target = items.firstIndex(where: { $0.id == targetID && !$0.done })
        else { return false }

        var reordered = items
        let item = reordered.remove(at: source)
        reordered.insert(item, at: target)
        items = reordered
        save()
        return true
    }

    func delete(_ id: UUID) {
        items.removeAll { $0.id == id }
        if focusID == id { focusID = nil }
        save()
    }

    func clearDone() {
        items.removeAll { $0.done }
        if let f = focusID, !items.contains(where: { $0.id == f }) { focusID = nil }
        save()
    }

    func toggleFocus(_ id: UUID) {
        focusID = (focusID == id) ? nil : id
    }

    var focusTitle: String? {
        items.first { $0.id == focusID }?.title
    }

    /// Dipanggil saat satu sesi fokus selesai: tambah hitungan pomodoro di tugas yang difokuskan.
    func creditFocusedTask() {
        guard let i = items.firstIndex(where: { $0.id == focusID }) else { return }
        items[i].pomodoros += 1
        save()
    }
}
