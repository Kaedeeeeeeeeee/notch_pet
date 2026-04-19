import Foundation

/// Static configuration for the NotchPet Supabase project (Tokyo region).
/// The anon key is a public credential designed to be shipped in the
/// client; it's scoped by RLS policies to the authed user's own data.
enum SupabaseConfig {
    static let projectURL = URL(string: "https://nixkjbltghhalbukjvqp.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5peGtqYmx0Z2hoYWxidWtqdnFwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY1ODU3MDEsImV4cCI6MjA5MjE2MTcwMX0.lJR6a3rvIRqqV2TSfZUUln7k1NWt1dYnHyx6Kw4SUcM"
}
