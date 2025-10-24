//
//  CouplePhotoCard.swift
//  Noi2
//
//  Created by Cristi Sandu on 23.10.2025.
//


import SwiftUI
import PhotosUI
import UIKit

struct CouplePhotoCard: View {
    @AppStorage("noi2_couple_photo") private var photoData: Data?
    @State private var selectedItem: PhotosPickerItem?
    @State private var uiImage: UIImage?
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LinearGradient(colors: [UITheme.accent.opacity(0.18), .clear],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(.ultraThinMaterial)
                    .shadow(radius: 8, y: 6)

                Group {
                    if let uiImage {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        VStack(spacing: 6) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 42, weight: .bold))
                                .symbolEffect(.bounce, value: pulse)
                                .onAppear { pulse.toggle() }
                            Text("Add your photo")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                }

                VStack {
                    HStack {
                        Label("You & Partner", systemImage: "heart.circle.fill")
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(.thinMaterial, in: Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                            .padding(12)
                        Spacer()
                    }
                    Spacer()
                }
            }

            HStack {
                PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                    Label(uiImage == nil ? "Choose photo" : "Change photo", systemImage: "photo.on.rectangle.angled")
                }
                .buttonStyle(.bordered)
                .tint(UITheme.accent)

                if uiImage != nil {
                    Button(role: .destructive) {
                        withAnimation(.spring) {
                            uiImage = nil
                            photoData = nil
                        }
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    let resized = image.resized(maxLength: 1200)
                    let out = resized.jpegData(compressionQuality: 0.85)
                    await MainActor.run {
                        self.uiImage = resized
                        self.photoData = out
                    }
                }
            }
        }
        .task {
            if let data = photoData, let img = UIImage(data: data) {
                uiImage = img
            }
        }
    }
}

// Helper for JPEG resize
fileprivate extension UIImage {
    func resized(maxLength: CGFloat) -> UIImage {
        let w = size.width, h = size.height
        let scale = min(1, maxLength / max(w, h))
        guard scale < 1 else { return self }
        let newSize = CGSize(width: floor(w * scale), height: floor(h * scale))
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in self.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
