import SwiftUI

struct PartnerCardsView: View {
    @State private var selectedCard: PartnerCommunicationCard?
    @State private var completedIDs: Set<String> = []

    var body: some View {
        List {
            Section {
                Text(String(localized: "partner.cards.privacy"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(TrainingData.partnerCards) { card in
                Button {
                    selectedCard = card
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: completedIDs.contains(card.id) ? "checkmark.circle.fill" : "message.circle.fill")
                            .font(.title2)
                            .foregroundStyle(completedIDs.contains(card.id) ? .green : .pink)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.title)
                                .font(.headline)
                            Text(card.prompt)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(String(localized: "partner.cards.title"))
        .onAppear { completedIDs = DataService.shared.loadCompletedPartnerCardIDs() }
        .sheet(item: $selectedCard) { card in
            NavigationStack {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.pink)
                    Text(card.title)
                        .font(.largeTitle.bold())
                    Text(card.prompt)
                        .font(.title3)
                    Text(String(localized: "partner.cards.consent"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(String(localized: "partner.cards.complete")) {
                        DataService.shared.markPartnerCardCompleted(card.id)
                        completedIDs.insert(card.id)
                        selectedCard = nil
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                }
                .padding(24)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "alert.cancel")) { selectedCard = nil }
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack { PartnerCardsView() }
}
