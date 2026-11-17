/*
 Create trip (Figma: 11 Create trip, 12 Trip created)
 Opened full screen from + on the Trips page. The form saves the trip with
 POST /api/v1/trips, then shows "Your trip is ready". Open day plan selects the
 new trip and goes to its Day plan; Back to trips closes and the trip is in the
 list under Upcoming (or Now if it starts today).

 Prototype differences from Figma:
 - No Ends row: trips have no end date in the backend yet.
 - Destination is required, because the backend needs it (Figma says only the
   name is needed).
 - No member roles: 12's "Set member roles" button (Figma 13-14) is replaced by
   Open day plan, and its text doesn't mention roles.
 */

import SwiftUI

struct CreateTripView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TripListStore.self) private var list
    // Opens a trip's Day plan, the same as tapping it on the Trips page
    var onOpen: (Trip) -> Void = { _ in }

    @State private var draft = NewTrip()
    @State private var isSaving = false
    @State private var failure: String?
    @State private var created: Trip?

    var body: some View {
        Group {
            if let created {
                TripCreatedView(trip: created,
                                onOpen: { dismiss(); onOpen(created) },
                                onDone: { dismiss() })
            } else {
                form
            }
        }
        .background(Theme.ground.ignoresSafeArea())
        .tint(Theme.forest)
        .interactiveDismissDisabled(isSaving)
        .alert("Couldn’t create trip", isPresented: Binding(
            get: { failure != nil }, set: { if !$0 { failure = nil } }
        )) {
            Button("OK", role: .cancel) { failure = nil }
        } message: { Text(failure ?? "") }
    }

    // MARK: - 11 Create trip

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Where are you going?")
                        .font(.system(size: 26, weight: .bold))
                        .tracking(-0.52)
                        .foregroundStyle(Theme.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text("Add a name, destination and start date. You can change anything later.")
                        .font(.bodyRegular)
                        .foregroundStyle(Theme.muted)
                }
                VStack(alignment: .leading, spacing: 8) {
                    CapsLabel(text: "Trip")
                    RowGroup {
                        textRow("Trip name", text: $draft.name, capitalization: .words)
                        textRow("Destination", text: $draft.destination, capitalization: .words)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    CapsLabel(text: "Dates")
                    RowGroup {
                        DetailRow(label: "Starts") {
                            DatePicker("Starts", selection: $draft.startDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .disabled(isSaving)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .safeAreaInset(edge: .bottom, spacing: 0) { createButton }
    }

    private var header: some View {
        ZStack {
            Text("New trip")
                .font(.navTitle)
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            HStack {
                Button("Cancel") { dismiss() }
                    .font(.bodyMedium)
                    .foregroundStyle(Theme.forest)
                    .frame(minWidth: 72, minHeight: 44, alignment: .leading)
                    .disabled(isSaving)
                Spacer()
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 20)
        .background(Theme.ground)
    }

    private func textRow(_ label: String, text: Binding<String>,
                         capitalization: TextInputAutocapitalization) -> some View {
        DetailRow(label: label) {
            TextField("Required", text: text)
                .font(.bodyRegular)
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(capitalization)
                .submitLabel(.done)
        }
    }

    private var createButton: some View {
        Button(isSaving ? "Creating…" : "Create trip", action: create)
            .buttonStyle(PillButtonStyle(filled: true))
            .disabled(!draft.isValid || isSaving)
            .opacity(draft.isValid && !isSaving ? 1 : 0.4)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .background(Theme.ground)
    }

    private func create() {
        guard draft.isValid, !isSaving else { return }
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                // The same draft (and trip ID) is reused on retry, so a retry can't duplicate it
                created = try await list.create(draft)
            } catch {
                failure = error.localizedDescription
            }
        }
    }
}

// MARK: - 12 Trip created

private struct TripCreatedView: View {
    let trip: Trip
    let onOpen: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: 14) {
                Image(systemName: "checkmark")
                    .font(.system(size: 30, weight: .regular))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 88, height: 88)
                    .background(Theme.tint, in: Circle())
                    .accessibilityHidden(true)
                Text("Your trip is ready")
                    .font(.system(size: 26, weight: .bold))
                    .tracking(-0.52)
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.name)
                        .font(.bodyEmphasis)
                        .tracking(-0.08)
                        .foregroundStyle(Theme.onAccent)
                    Text("\(trip.startText()) · \(trip.destination)")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.onAccent.opacity(0.82))
                }
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .background(Theme.forest, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .accessibilityElement(children: .combine)
                Text("You’re the Leader. Add activities to start planning.")
                    .font(.bodyRegular)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            Spacer(minLength: 0)
            VStack(spacing: 10) {
                Button("Open day plan", action: onOpen)
                    .buttonStyle(PillButtonStyle(filled: true))
                Button("Back to trips", action: onDone)
                    .buttonStyle(TextButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
    }
}

#Preview("11 Create trip") {
    CreateTripView()
        .environment(TripListStore(previewTrips: Trip.samples))
}

#Preview("12 Trip created") {
    TripCreatedView(trip: Trip.samples[1], onOpen: {}, onDone: {})
        .background(Theme.ground)
}
