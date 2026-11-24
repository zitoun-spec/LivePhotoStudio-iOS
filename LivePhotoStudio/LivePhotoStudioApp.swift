import SwiftUI

@main
struct LivePhotoStudioApp: App {
    var body: some Scene {
        WindowGroup {
            StudioView()
                .preferredColorScheme(.dark)
        }
    }
}
