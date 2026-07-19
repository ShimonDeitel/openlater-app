import SwiftUI
import PhotosUI

struct CreateCapsuleView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var body_ = ""
    @State private var kind: CapsuleKind = .text
    @State private var unlockDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var recurrence: RecurrenceRule = .none
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @StateObject private var recorder = VoiceRecorder()
    @State private var showingPaywall = false

    var body: some View {
        NavigationStack {
            ZStack {
                OpenlaterColor.paper.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        titleField
                        kindPicker
                        contentEditor
                        unlockDatePicker
                        recurrencePicker
                        Spacer(minLength: 8)
                    }
                    .padding(20)
                }
            }
            .dismissKeyboardOnTap()
            .navigationTitle("Seal a letter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        recorder.discardPending()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Seal it") { save() }
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingPaywall) { PaywallView() }
        }
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TITLE").font(OpenlaterFont.label()).foregroundStyle(OpenlaterColor.inkMuted)
            TextField("A letter for...", text: $title)
                .font(OpenlaterFont.serifHeadline(17))
                .padding(12)
                .background(OpenlaterColor.paperPanel)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var kindPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("KIND").font(OpenlaterFont.label()).foregroundStyle(OpenlaterColor.inkMuted)
            HStack(spacing: 10) {
                kindButton(.text, icon: "text.alignleft", label: "Text")
                kindButton(.photo, icon: "photo", label: "Photo")
                kindButton(.voice, icon: "waveform", label: "Voice")
            }
        }
    }

    private func kindButton(_ k: CapsuleKind, icon: String, label: String) -> some View {
        let locked = !CapsuleGating.canUseKind(k, isPro: store.isPro)
        return Button {
            if locked { showingPaywall = true } else { kind = k }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                Text(label).font(OpenlaterFont.label(11))
                if locked { ProBadge() }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(kind == k ? OpenlaterColor.wax.opacity(0.15) : OpenlaterColor.paperPanel)
            .foregroundStyle(kind == k ? OpenlaterColor.wax : OpenlaterColor.ink)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(kind == k ? OpenlaterColor.wax : OpenlaterColor.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var contentEditor: some View {
        switch kind {
        case .text:
            VStack(alignment: .leading, spacing: 6) {
                Text("YOUR LETTER").font(OpenlaterFont.label()).foregroundStyle(OpenlaterColor.inkMuted)
                TextEditor(text: $body_)
                    .font(OpenlaterFont.body())
                    .frame(minHeight: 160)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(OpenlaterColor.paperPanel)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        case .photo:
            VStack(alignment: .leading, spacing: 6) {
                Text("PHOTO").font(OpenlaterFont.label()).foregroundStyle(OpenlaterColor.inkMuted)
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    if let selectedImage {
                        Image(uiImage: selectedImage)
                            .resizable().scaledToFill()
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.badge.plus").font(.system(size: 32))
                            Text("Choose a photo").font(OpenlaterFont.body(14))
                        }
                        .frame(maxWidth: .infinity, minHeight: 160)
                        .foregroundStyle(OpenlaterColor.inkMuted)
                        .background(OpenlaterColor.paperPanel)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .onChange(of: selectedPhotoItem) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                            selectedImage = img
                        }
                    }
                }
                TextField("Add a caption (optional)", text: $body_)
                    .padding(10)
                    .background(OpenlaterColor.paperPanel)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        case .voice:
            VStack(alignment: .leading, spacing: 10) {
                Text("VOICE MEMO").font(OpenlaterFont.label()).foregroundStyle(OpenlaterColor.inkMuted)
                HStack(spacing: 16) {
                    Button {
                        if recorder.isRecording {
                            recorder.stopRecording()
                        } else {
                            recorder.requestPermission { granted in
                                if granted { recorder.startRecording() } else { recorder.permissionDenied = true }
                            }
                        }
                    } label: {
                        Image(systemName: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(OpenlaterColor.wax)
                    }
                    Text(recorder.isRecording ? "Recording… \(Int(recorder.recordedDuration))s" : (recorder.pendingFilename != nil ? "Voice memo recorded" : "Tap to record"))
                        .font(OpenlaterFont.body(14))
                        .foregroundStyle(OpenlaterColor.inkMuted)
                }
                if recorder.permissionDenied {
                    Text("Microphone access is off. Enable it in Settings to record a voice memo.")
                        .font(OpenlaterFont.mono(11))
                        .foregroundStyle(OpenlaterColor.wax)
                }
            }
        }
    }

    private var unlockDatePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("OPEN WHEN…").font(OpenlaterFont.label()).foregroundStyle(OpenlaterColor.inkMuted)
            DatePicker("", selection: $unlockDate, in: Date()..., displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(OpenlaterColor.wax)
                .padding(10)
                .background(OpenlaterColor.paperPanel)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var recurrencePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("RE-SEAL").font(OpenlaterFont.label()).foregroundStyle(OpenlaterColor.inkMuted)
                if !store.isPro { ProBadge() }
            }
            Picker("Recurrence", selection: $recurrence) {
                ForEach(RecurrenceRule.allCases) { rule in
                    Text(rule.label).tag(rule)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!store.isPro)
            .onChange(of: recurrence) { _, newValue in
                if !CapsuleGating.canUseRecurrence(newValue, isPro: store.isPro) {
                    recurrence = .none
                    showingPaywall = true
                }
            }
        }
    }

    private var canSave: Bool {
        switch kind {
        case .text: return !body_.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .photo: return selectedImage != nil
        case .voice: return recorder.pendingFilename != nil
        }
    }

    private func save() {
        var mediaFilename: String?
        switch kind {
        case .text:
            break
        case .photo:
            if let selectedImage { mediaFilename = MediaStore.savePhoto(selectedImage) }
        case .voice:
            mediaFilename = recorder.stopRecording()
        }
        let capsule = LetterCapsule(
            title: title,
            kind: kind,
            textBody: body_,
            mediaFilename: mediaFilename,
            createdAt: appModel.clock.now(),
            unlockDate: unlockDate,
            recurrence: recurrence
        )
        appModel.addCapsule(capsule)
        dismiss()
    }
}
