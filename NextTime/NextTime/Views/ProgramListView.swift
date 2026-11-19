import SwiftUI

/// Only the current four-stage path is offered; archived courses have no start entry.
struct ProgramListView: View {
    var body: some View { NavigationStack { PracticePathView() } }
}
