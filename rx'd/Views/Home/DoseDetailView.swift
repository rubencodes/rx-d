import PhotosUI
import SwiftData
import SwiftUI
import WidgetKit

struct DoseDetailView: View {
    let occurrence: ScheduledOccurrence

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var noteText = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photoImage: UIImage?
    @State private var photoFilename: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Prescription", value: occurrence.prescription.name)
                    LabeledContent("Scheduled") {
                        Text(occurrence.scheduledDate, style: .time)
                    }
                    LabeledContent("Status", value: occurrence.effectiveStatus.label)
                }

                Section("Actions") {
                    Button {
                        mark(.taken, completed: true)
                    } label: {
                        Label("Mark Taken", systemImage: "checkmark.circle.fill")
                    }
                    .disabled(occurrence.effectiveStatus == .taken)

                    Button {
                        mark(.snoozed, completed: false)
                    } label: {
                        Label("Snooze", systemImage: "clock.badge")
                    }
                }

                Section("Note") {
                    TextField("Add a note", text: $noteText, axis: .vertical)
                        .lineLimit(2 ... 5)
                }

                Section("Photo") {
                    if let photoImage {
                        Image(uiImage: photoImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    PhotosPicker(
                        selection: $photoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label(photoImage == nil ? "Add Photo" : "Change Photo",
                              systemImage: "camera")
                    }
                    if photoImage != nil {
                        Button("Remove Photo", role: .destructive) {
                            removePhoto()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Dose")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveNoteAndPhoto(); dismiss() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear(perform: load)
            .onChange(of: photoItem) { _, newItem in
                Task { await loadPickedPhoto(newItem) }
            }
        }
    }

    private func load() {
        noteText = occurrence.doseLog?.noteText ?? ""
        photoFilename = occurrence.doseLog?.photoFilename
        if let filename = photoFilename {
            photoImage = PhotoStore.load(filename)
        }
    }

    private func loadPickedPhoto(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        // Replace any previous file
        if let old = photoFilename { PhotoStore.delete(old) }
        photoFilename = PhotoStore.save(image)
        photoImage = image
    }

    private func removePhoto() {
        if let filename = photoFilename { PhotoStore.delete(filename) }
        photoFilename = nil
        photoImage = nil
        photoItem = nil
    }

    private func logForWriting() -> DoseLog {
        if let existing = occurrence.doseLog { return existing }
        let log = DoseLog(
            prescriptionId: occurrence.prescription.id,
            scheduledDate: occurrence.scheduledDate,
            status: occurrence.effectiveStatus == .missed ? .missed : .pending
        )
        context.insert(log)
        return log
    }

    private func mark(_ status: DoseStatus, completed: Bool) {
        let log = logForWriting()
        log.status = status
        log.completedAt = completed ? Date() : nil
        if status == .snoozed { log.snoozeCount += 1 }
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func saveNoteAndPhoto() {
        let log = logForWriting()
        log.noteText = noteText.isEmpty ? nil : noteText
        log.photoFilename = photoFilename
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
