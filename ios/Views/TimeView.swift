/*
 Time Page
 Displays current time
 */

import SwiftUI
import Combine

struct TimeView: View {
    // Get current time from local info
    @State private var currentTime = Date()

    // create timer to update every second
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // UI
    var body: some View {
        VStack(spacing: 16) {
            Text("Current Time")
                .font(.title2)
                .foregroundStyle(.secondary)

            // e.g. "9:53 PM"
            Text(currentTime.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .padding()
        .navigationTitle("Time")

        // listens for timer refresh, updates current time
        .onReceive(timer) { newTime in
            currentTime = newTime
        }
    }
}

#Preview {
    NavigationStack {
        TimeView()
    }
}
