import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack {
                Image(systemName: "pawprint.fill")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                    .font(.system(size: 60))

                Text("WoofWalk")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()

                Text("Dog Walking Companion")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .navigationTitle("Home")
        }
    }
}

#Preview {
    ContentView()
}
