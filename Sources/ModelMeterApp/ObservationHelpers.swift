import Observation

@MainActor
func observeChanges(
    tracking: () -> Void,
    onChange: @escaping @MainActor @Sendable () -> Void
) {
    withObservationTracking {
        tracking()
    } onChange: {
        Task { @MainActor in
            onChange()
        }
    }
}
