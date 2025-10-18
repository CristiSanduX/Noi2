//
//  LoveMessageService.swift
//  Noi2
//
//  Created by Cristi Sandu on 16.10.2025.
//

import FirebaseFirestore
import WidgetKit

final class LoveMessageService {
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var isListening = false

    func send(to coupleId: String, text: String, fromUid: String, fromName: String) {
        guard !coupleId.isEmpty else { return }
        let data: [String: Any] = [
            "text": text,
            "fromUid": fromUid,
            "fromName": fromName,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        db.collection("couples").document(coupleId)
            .setData(["lastMessage": data], merge: true)
    }

    func startListening(coupleId: String, currentUid: String) {
        stopListening()
        guard !coupleId.isEmpty else { return }

        isListening = true
        listener = db.collection("couples").document(coupleId)
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snap, _ in
                guard let self = self else { return }
                guard
                    let data = snap?.data(),
                    let last = data["lastMessage"] as? [String: Any],
                    let text = last["text"] as? String,
                    let fromUid = last["fromUid"] as? String,
                    let fromName = last["fromName"] as? String
                else { return }

                guard fromUid != currentUid else { return }

                let note = LoveNote(text: text, fromUid: fromUid, fromName: fromName, updatedAt: Date())
                LoveStore.save(note)
                WidgetCenter.shared.reloadTimelines(ofKind: "Noi2LoveWidget")
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        isListening = false
    }
}
