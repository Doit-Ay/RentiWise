import SwiftUI

struct ManageDataView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // Simple list of rows
                    NavigationLink("Profile Information") {
                        // Placeholder detail view
                        Text("Profile Information")
                            .navigationTitle("Profile Information")
                            .navigationBarTitleDisplayMode(.inline)
                    }
                    NavigationLink("Booking History") {
                        // Placeholder detail view
                        Text("Booking History")
                            .navigationTitle("Booking History")
                            .navigationBarTitleDisplayMode(.inline)
                    }
                    NavigationLink("Payment History") {
                        // Placeholder detail view
                        Text("Payment History")
                            .navigationTitle("Payment History")
                            .navigationBarTitleDisplayMode(.inline)
                    }
                }

                Section {
                    // Bottom action buttons
                    Button("Download My Data") {
                        // No backend logic — UI only
                    }

                    Button(role: .destructive) {
                        // No backend logic — UI only
                    } label: {
                        Text("Delete Account")
                    }
                }
            }
            .navigationTitle("Manage Data")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ManageDataView()
}
