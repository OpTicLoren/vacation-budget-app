
//
//  ContentView.swift
//  Vacation Budget App
//
//  Created by Loren Harrison Franck on 6/19/25.
//

import SwiftUI

// MARK: - Currency Support
enum Currency: String, CaseIterable, Codable, Identifiable {
    case usd = "USD"
    case eur = "EUR"
    case gbp = "GBP"
    case jpy = "JPY"
    case try_ = "TRY"
    case mxn = "MXN"
    case aud = "AUD"
    case cad = "CAD"
    case chf = "CHF"
    case cny = "CNY"
    
    var id: String { rawValue }
    
    var symbol: String {
        switch self {
        case .usd: return "$"
        case .eur: return "€"
        case .gbp: return "£"
        case .jpy: return "JP¥"
        case .try_: return "₺"
        case .mxn: return "MXN$"
        case .aud: return "AUD$"
        case .cad: return "CAD$"
        case .chf: return "CHF"
        case .cny: return "CN¥"
        }
    }
    
    var name: String {
        switch self {
        case .usd: return "US Dollar"
        case .eur: return "Euro"
        case .gbp: return "British Pound"
        case .jpy: return "Japanese Yen"
        case .try_: return "Turkish Lira"
        case .mxn: return "Mexican Peso"
        case .aud: return "Australian Dollar"
        case .cad: return "Canadian Dollar"
        case .chf: return "Swiss Franc"
        case .cny: return "Chinese Yuan"
        }
    }
}

// MARK: - Exchange Rate Service
class ExchangeRateService: ObservableObject {
    @Published var exchangeRates: [String: Double] = [:]
    @Published var lastUpdated: Date?
    
    private let apiKey = "8c482ff794ee9fc127685577"
    private let baseURL = "https://v6.exchangerate-api.com/v6"
    
    @MainActor
    func fetchExchangeRates() async {
        guard let url = URL(string: "\(baseURL)/\(apiKey)/latest/USD") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(ExchangeRateResponse.self, from: data)
            
            self.exchangeRates = response.conversion_rates
            self.lastUpdated = Date()
        } catch {
            print("Failed to fetch exchange rates: \(error)")
        }
    }
    
    func convertAmount(_ amount: Double, from: Currency, to: Currency) -> Double {
        if from == to { return amount }
        
        // Convert to USD first, then to target currency
        let usdAmount: Double
        if from == .usd {
            usdAmount = amount
        } else {
            guard let fromRate = exchangeRates[from.rawValue] else { return amount }
            usdAmount = amount / fromRate
        }
        
        if to == .usd {
            return usdAmount
        } else {
            guard let toRate = exchangeRates[to.rawValue] else { return amount }
            return usdAmount * toRate
        }
    }
}

struct ExchangeRateResponse: Codable {
    let conversion_rates: [String: Double]
}

// MARK: - Currency Formatting Helper
func formatCurrency(_ amount: Double, currency: Currency = .usd) -> String {
    let formattedNumber: String
    if amount.truncatingRemainder(dividingBy: 1) == 0 {
        formattedNumber = String(format: "%.0f", amount)
    } else {
        formattedNumber = String(format: "%.2f", amount)
    }
    return "\(currency.symbol)\(formattedNumber)"
}

func formatCurrencyWithUSDEquivalent(_ amount: Double, currency: Currency, exchangeService: ExchangeRateService) -> String {
    let primaryAmount = formatCurrency(amount, currency: currency)
    
    if currency == .usd {
        return primaryAmount
    }
    
    let usdAmount = exchangeService.convertAmount(amount, from: currency, to: .usd)
    let usdFormatted = formatCurrency(usdAmount, currency: .usd)
    
    return "\(primaryAmount) (\(usdFormatted))"
}

// MARK: - Color Extensions
extension Color {
    static let primaryPink = Color(red: 1.0, green: 0.2, blue: 0.8)
    static let secondaryPink = Color(red: 1.0, green: 0.4, blue: 0.9)
    static let lightPink = Color(red: 1.0, green: 0.6, blue: 0.95)
    
    // Dark mode colors
    static let darkBackground = Color(red: 0.1, green: 0.1, blue: 0.1)
    static let darkCard = Color(red: 0.15, green: 0.15, blue: 0.15)
    static let darkText = Color.white
    static let darkSecondaryText = Color.gray
}

struct ExpenseCategory: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var plannedAmount: Double
}

struct Expense: Identifiable, Codable, Equatable {
    let id: UUID
    var categoryId: UUID
    var amount: Double
    var description: String
    var date: Date
}

struct Trip: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var budget: Double
    var currency: Currency // Added currency field with migration support
    var icon: String // Added icon field
    var expectedCategories: [ExpenseCategory]
    var actualExpenses: [Expense]
    var startDate: Date?
    var endDate: Date?
    var lastUpdated: Date
    
    // CRITICAL: Custom decoding to handle missing currency field in old data
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        budget = try container.decode(Double.self, forKey: .budget)
        
        // Handle currency with fallback for old data
        currency = try container.decodeIfPresent(Currency.self, forKey: .currency) ?? .usd
        
        icon = try container.decode(String.self, forKey: .icon)
        expectedCategories = try container.decode([ExpenseCategory].self, forKey: .expectedCategories)
        actualExpenses = try container.decode([Expense].self, forKey: .actualExpenses)
        startDate = try container.decodeIfPresent(Date.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
    }
    
    // Default initializer for new trips
    init(id: UUID, name: String, budget: Double, currency: Currency = .usd, icon: String, expectedCategories: [ExpenseCategory], actualExpenses: [Expense], startDate: Date?, endDate: Date?, lastUpdated: Date) {
        self.id = id
        self.name = name
        self.budget = budget
        self.currency = currency
        self.icon = icon
        self.expectedCategories = expectedCategories
        self.actualExpenses = actualExpenses
        self.startDate = startDate
        self.endDate = endDate
        self.lastUpdated = lastUpdated
    }
}

class TripStore: ObservableObject {
    @Published var trips: [Trip] = [] {
        didSet { save() }
    }
    @Published var yearlyBudget: Double = 0 {
        didSet { saveYearlyBudget() }
    }
    @Published var globalCurrency: Currency = .usd {
        didSet { saveGlobalCurrency() }
    }
    
    private var previousGlobalCurrency: Currency = .usd
    
    let exchangeRateService = ExchangeRateService()
    
    let tripsKey = "trips_key"
    let yearlyBudgetKey = "yearly_budget_key"
    let globalCurrencyKey = "global_currency_key"
    
    var activeTrips: [Trip] { trips.filter { !isPastTrip($0) } }
    var pastTrips: [Trip] { trips.filter { isPastTrip($0) } }
    
    var totalSpentThisYear: Double {
        trips.reduce(0) { total, trip in
            total + trip.actualExpenses.reduce(0) { $0 + $1.amount }
        }
    }
    
    var totalExpectedThisYear: Double {
        activeTrips.reduce(0) { total, trip in
            // Convert trip budget to global currency
            total + exchangeRateService.convertAmount(trip.budget, from: trip.currency, to: globalCurrency)
        }
    }
    
    var lifetimeSavings: Double {
        pastTrips.reduce(0) { total, trip in
            let totalSpent = trip.actualExpenses.reduce(0) { $0 + $1.amount }
            let savings = trip.budget - totalSpent
            // Convert savings to global currency
            return total + exchangeRateService.convertAmount(savings, from: trip.currency, to: globalCurrency)
        }
    }
    
    var hasCompletedTrips: Bool {
        !pastTrips.isEmpty
    }
    
    private func isPastTrip(_ trip: Trip) -> Bool {
        guard let endDate = trip.endDate else { return false }
        return endDate < Date() // Only trips with end dates before today are past trips
    }
    
    init() {
        // Initialize defaults
        trips = []
        yearlyBudget = 0
        globalCurrency = .usd
        previousGlobalCurrency = .usd
        
        // Force load all data
        loadYearlyBudget()
        loadGlobalCurrency()
        previousGlobalCurrency = globalCurrency
        load()
    }
    
    func addTrip(name: String, budget: Double, currency: Currency, icon: String, startDate: Date?, endDate: Date?) {
        let trip = Trip(id: UUID(), name: name, budget: budget, currency: currency, icon: icon, expectedCategories: [], actualExpenses: [], startDate: startDate, endDate: endDate, lastUpdated: Date())
        trips.append(trip)
    }
    
    func updateTrip(_ trip: Trip) {
        if let idx = trips.firstIndex(where: { $0.id == trip.id }) {
            var updated = trip
            updated.lastUpdated = Date()
            trips[idx] = updated
        }
    }
    
    func deleteTrip(at offsets: IndexSet) {
        for idx in offsets {
            let trip = activeTrips[idx]
            trips.removeAll { $0.id == trip.id }
        }
    }
    
    func permanentlyDeleteTrip(_ trip: Trip) {
        trips.removeAll { $0.id == trip.id }
    }
    
    func archiveTrip(_ trip: Trip) {
        if let idx = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[idx].endDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        }
    }
    

    
    // CRITICAL: Emergency data recovery function
    func attemptDataRecovery() -> Bool {
        print("🚨 Attempting emergency data recovery...")
        
        // Check all possible backup locations
        let backupKeys = ["\(tripsKey)_backup", "\(tripsKey)_current", tripsKey]
        
        for backupKey in backupKeys {
            if let data = UserDefaults.standard.data(forKey: backupKey) {
                do {
                    let recovered = try JSONDecoder().decode([Trip].self, from: data)
                    if !recovered.isEmpty {
                        trips = recovered
                        print("✅ Successfully recovered \(recovered.count) trips from \(backupKey)")
                        return true
                    }
                } catch {
                    print("❌ Failed to decode from \(backupKey): \(error)")
                    continue
                }
            }
        }
        
        print("❌ No recoverable data found")
        return false
    }
    
    // Convert all trips to global currency
    @MainActor
    func convertAllTripsToGlobalCurrency() async {
        await exchangeRateService.fetchExchangeRates()
        
        let oldCurrency = previousGlobalCurrency
        
        // Convert yearly budget
        if yearlyBudget > 0 {
            yearlyBudget = exchangeRateService.convertAmount(yearlyBudget, from: oldCurrency, to: globalCurrency)
        }
        
        for i in 0..<trips.count {
            var trip = trips[i]
            let originalCurrency = trip.currency
            
            if originalCurrency != globalCurrency {
                // Convert trip budget
                trip.budget = exchangeRateService.convertAmount(trip.budget, from: originalCurrency, to: globalCurrency)
                
                // Convert all expected categories
                for j in 0..<trip.expectedCategories.count {
                    trip.expectedCategories[j].plannedAmount = exchangeRateService.convertAmount(
                        trip.expectedCategories[j].plannedAmount, 
                        from: originalCurrency, 
                        to: globalCurrency
                    )
                }
                
                // Convert all actual expenses
                for j in 0..<trip.actualExpenses.count {
                    trip.actualExpenses[j].amount = exchangeRateService.convertAmount(
                        trip.actualExpenses[j].amount, 
                        from: originalCurrency, 
                        to: globalCurrency
                    )
                }
                
                // Update currency
                trip.currency = globalCurrency
                trips[i] = trip
            }
        }
        
        // Update previous currency for next conversion
        previousGlobalCurrency = globalCurrency
        
        print("✅ Converted all trips and yearly budget from \(oldCurrency.name) to \(globalCurrency.name)")
    }
    
    private func save() {
        do {
            // CRITICAL: Always create backup before saving new data
            if let existingData = UserDefaults.standard.data(forKey: tripsKey) {
                UserDefaults.standard.set(existingData, forKey: "\(tripsKey)_backup")
            }
            
            let data = try JSONEncoder().encode(trips)
            UserDefaults.standard.set(data, forKey: tripsKey)
            
            // Additional safety: Save to secondary key
            UserDefaults.standard.set(data, forKey: "\(tripsKey)_current")
            
            print("✅ Data saved successfully with backup")
        } catch {
            print("❌ CRITICAL ERROR: Failed to save trip data: \(error)")
            // Restore from backup if save fails
            if let backupData = UserDefaults.standard.data(forKey: "\(tripsKey)_backup") {
                UserDefaults.standard.set(backupData, forKey: tripsKey)
                print("🔄 Restored from backup due to save failure")
            }
        }
    }
    
    private func load() {
        print("🚨 Starting data load process...")
        
        // Check all possible backup locations
        let backupKeys = [tripsKey, "\(tripsKey)_backup", "\(tripsKey)_current"]
        
        for backupKey in backupKeys {
            print("🔍 Checking key: \(backupKey)")
            if let data = UserDefaults.standard.data(forKey: backupKey) {
                print("📦 Found data for key: \(backupKey), size: \(data.count) bytes")
                do {
                    let recovered = try JSONDecoder().decode([Trip].self, from: data)
                    if !recovered.isEmpty {
                        trips = recovered
                        print("✅ Successfully loaded \(recovered.count) trips from \(backupKey)")
                        return
                    } else {
                        print("⚠️ Data found but empty array in \(backupKey)")
                    }
                } catch {
                    print("❌ Failed to decode from \(backupKey): \(error)")
                    continue
                }
            } else {
                print("❌ No data found for key: \(backupKey)")
            }
        }
        
        // If all else fails, start with empty array
        trips = []
        print("⚠️ Starting with empty trip list - no recoverable data found")
    }
    
    private func saveYearlyBudget() {
        UserDefaults.standard.set(yearlyBudget, forKey: yearlyBudgetKey)
    }
    
    private func loadYearlyBudget() {
        yearlyBudget = UserDefaults.standard.double(forKey: yearlyBudgetKey)
    }
    
    private func saveGlobalCurrency() {
        UserDefaults.standard.set(globalCurrency.rawValue, forKey: globalCurrencyKey)
    }
    
    private func loadGlobalCurrency() {
        if let currencyString = UserDefaults.standard.string(forKey: globalCurrencyKey),
           let currency = Currency(rawValue: currencyString) {
            globalCurrency = currency
        }
    }
}

struct ContentView: View {
    @StateObject private var store = TripStore()
    @StateObject private var exchangeRateService = ExchangeRateService()
    @State private var showingAddTrip = false
    @AppStorage("darkMode") private var darkMode = false
    @State private var selectedTripId: UUID? = nil
    @State private var sortOption: SortOption = .manual
    @State private var showingSettings = false
    @State private var showingYearlyBudgetEdit = false
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var showDatePickers = false
    @State private var showYearlyBudgetWarning = false
    @State private var pendingTripName = ""
    @State private var pendingTripBudget: Double = 0
    @State private var pendingTripCurrency: Currency = .usd
    @State private var pendingTripIcon = ""
    @State private var pendingTripStartDate: Date? = nil
    @State private var pendingTripEndDate: Date? = nil
    @State private var isEditingTrip = false
    @State private var editingTripId: UUID? = nil
    enum SortOption: String, CaseIterable, Identifiable {
        case manual = "Manual"
        case date = "Date"
        var id: String { rawValue }
    }
    var sortedActiveTrips: [Trip] {
        switch sortOption {
        case .manual: return store.activeTrips
        case .date: return store.activeTrips.sorted { ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast) }
        }
    }
    
    var sortedPastTrips: [Trip] {
        store.pastTrips.sorted { ($0.endDate ?? .distantFuture) > ($1.endDate ?? .distantFuture) }
    }
    func deleteActiveTrip(at offsets: IndexSet) {
        for index in offsets {
            let trip = sortedActiveTrips[index]
            if let storeIndex = store.activeTrips.firstIndex(where: { $0.id == trip.id }) {
                store.deleteTrip(at: IndexSet([storeIndex]))
            }
        }
    }
    
    func deletePastTrip(at offsets: IndexSet) {
        for index in offsets {
            let trip = sortedPastTrips[index]
            store.permanentlyDeleteTrip(trip)
        }
    }
    
    func archiveActiveTrip(_ trip: Trip) {
        store.archiveTrip(trip)
    }
    
    func deletePastTripById(_ tripId: UUID) {
        if let trip = sortedPastTrips.first(where: { $0.id == tripId }) {
            store.permanentlyDeleteTrip(trip)
        }
    }
    
    func restorePastTrip(_ trip: Trip) {
        if let idx = store.trips.firstIndex(where: { $0.id == trip.id }) {
            store.trips[idx].endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())
        }
    }
    
    func calculateYearlyBudgetOverage(newTripBudget: Double, editingTripId: UUID? = nil) -> Double {
        guard store.yearlyBudget > 0 else { return 0 }
        
        // Calculate current total of expected trip budgets excluding the trip being edited
        let currentExpectedTotal = store.activeTrips.filter { trip in
            if let editingId = editingTripId {
                return trip.id != editingId
            }
            return true
        }.reduce(0) { total, trip in
            // Convert trip budget to global currency for comparison
            return total + store.exchangeRateService.convertAmount(trip.budget, from: trip.currency, to: store.globalCurrency)
        }
        
        // Convert new trip budget to global currency
        let newBudgetInGlobalCurrency = store.exchangeRateService.convertAmount(newTripBudget, from: pendingTripCurrency, to: store.globalCurrency)
        
        let newExpectedTotal = currentExpectedTotal + newBudgetInGlobalCurrency
        return max(0, newExpectedTotal - store.yearlyBudget)
    }
    
    func savePendingTrip() {
        if isEditingTrip, let tripId = editingTripId {
            // Edit existing trip
            if let idx = store.trips.firstIndex(where: { $0.id == tripId }) {
                store.trips[idx].name = pendingTripName
                store.trips[idx].budget = pendingTripBudget
                store.trips[idx].currency = pendingTripCurrency
                store.trips[idx].icon = pendingTripIcon
                store.trips[idx].startDate = pendingTripStartDate
                store.trips[idx].endDate = pendingTripEndDate
                store.trips[idx].lastUpdated = Date()
            }
        } else {
            // Add new trip
            store.addTrip(name: pendingTripName, budget: pendingTripBudget, currency: pendingTripCurrency, icon: pendingTripIcon, startDate: pendingTripStartDate, endDate: pendingTripEndDate)
            if let newTrip = store.activeTrips.last {
                selectedTripId = newTrip.id
            }
            showingAddTrip = false
        }
        
        // Reset pending data
        pendingTripName = ""
        pendingTripBudget = 0
        pendingTripCurrency = .usd
        pendingTripIcon = ""
        pendingTripStartDate = nil
        pendingTripEndDate = nil
        isEditingTrip = false
        editingTripId = nil
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                (darkMode ? Color.darkBackground : Color.white)
                    .ignoresSafeArea()
                if sortedActiveTrips.isEmpty && sortedPastTrips.isEmpty {
                    ZStack {
                        // Canva-inspired gradient background - bottom half only
                    VStack {
                        Spacer()
                            
                            // Bottom gradient wave effect like Canva
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.clear,
                                            Color.lightPink.opacity(0.3),
                                            Color.primaryPink.opacity(0.6),
                                            Color.secondaryPink.opacity(0.8)
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: UIScreen.main.bounds.height * 0.6)
                                .blur(radius: 20)
                                .overlay(
                                    // Additional gradient overlay for depth
                                    Rectangle()
                                        .fill(
                                            RadialGradient(
                                                gradient: Gradient(colors: [
                                                    Color.primaryPink.opacity(0.4),
                                                    Color.clear
                                                ]),
                                                center: .bottomTrailing,
                                                startRadius: 100,
                                                endRadius: 400
                                            )
                                        )
                                        .blur(radius: 30)
                                )
                        }
                        
                        // Main content with proper centering
                        VStack(spacing: 0) {
                            Spacer()
                            
                            // App title with designer typography
                            VStack(spacing: 24) {
                                Text("Vacation Budget App")
                                    .font(.system(size: 42, weight: .black, design: .rounded))
                                    .foregroundColor(darkMode ? .darkText : .black)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .kerning(0.5)
                                
                                // Improved tagline with comma and emoji
                                Text("Save time and money on travel,\nwithout spreadsheets 🥱")
                                    .font(.system(size: 18, weight: .medium, design: .rounded))
                                    .foregroundColor(darkMode ? .darkSecondaryText : .black.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(2)
                                
                                // Add Trip Button - moved higher and made bigger
                        Button(action: { showingAddTrip = true }) {
                                    HStack(spacing: 14) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 26, weight: .semibold))
                                Text("Add Trip")
                                            .font(.system(size: 24, weight: .bold, design: .rounded))
                                    }
                                    .padding(.horizontal, 48)
                                    .padding(.vertical, 20)
                                    .background(
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [Color.primaryPink, Color.secondaryPink]),
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                    )
                            .foregroundColor(.white)
                                    .shadow(color: Color.primaryPink.opacity(0.4), radius: 20, x: 0, y: 8)
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                        }
                        .accessibilityLabel("Add Trip")
                            }
                            .padding(.horizontal, 32)
                            
                        Spacer()
                            Spacer() // Extra spacer for better bottom positioning
                    }
                        
                        // Settings button overlay with mode tip
                        VStack {
                        HStack {
                            Button(action: { showingSettings = true }) {
                                Image(systemName: "gearshape.fill")
                                        .font(.system(size: 22, weight: .medium))
                                        .foregroundColor(.primaryPink)
                                        .padding(14)
                                        .background(
                                            Circle()
                                                .fill(Color.white.opacity(darkMode ? 0.15 : 0.95))
                                                .shadow(color: Color.primaryPink.opacity(0.2), radius: 12, x: 0, y: 6)
                                        )
                                }
                                .accessibilityLabel("Settings")
                            
                            // Mode tip with arrow - showing opposite theme colors
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.left")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(darkMode ? Color.white : Color.black)
                                Text(darkMode ? "Try Light Mode!" : "Try Dark Mode!")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(darkMode ? Color.white : Color.black)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(darkMode ? Color.black.opacity(0.8) : Color.white.opacity(0.9))
                                    .shadow(color: (darkMode ? Color.black : Color.white).opacity(0.3), radius: 8, x: 0, y: 4)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(darkMode ? Color.white.opacity(0.3) : Color.black.opacity(0.2), lineWidth: 1)
                            )
                            .opacity(0.9)
                            
                            Spacer()
                        }
                            .padding(.top, 60)
                        .padding(.leading, 24)
                            Spacer()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Trips")
                                .font(.system(size: 48, weight: .heavy, design: .default))
                                .foregroundColor(darkMode ? .darkText : .black)
                            Spacer()
                            Button(action: { showingSettings = true }) {
                                Image(systemName: "gearshape.fill")
                                    .resizable()
                                    .frame(width: 28, height: 28)
                                    .foregroundColor(.primaryPink)
                                    .padding(12)
                                    .background(Circle().fill(Color.lightPink.opacity(0.3)))
                                    .shadow(color: .primaryPink.opacity(0.2), radius: 4, x: 0, y: 2)
                            }
                            .accessibilityLabel("Settings")
                        }
                        .padding(.horizontal)
                        .padding(.top, 32)
                        
                        // Yearly Budget Section with proper spacing
                        YearlyBudgetView(store: store, showingEdit: $showingYearlyBudgetEdit)
                            .padding(.horizontal)
                            .padding(.top, 24)
                        
                        // Sort menu with balanced spacing
                        HStack {
                            Menu {
                                ForEach(SortOption.allCases) { option in
                                    Button(option.rawValue) { sortOption = option }
                                }
                            } label: {
                                Label("Sort", systemImage: "arrow.up.arrow.down")
                                    .foregroundColor(.primaryPink)
                                    .font(.system(size: 16, weight: .medium))
                            }
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 14)
                        .padding(.bottom, 14)
                        List {
                            if !sortedActiveTrips.isEmpty {
                                Section {
                                    // Custom header that respects dark mode
                                    HStack {
                                        Text("Active Trips")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(darkMode ? .darkText : .black)
                                            .padding(.horizontal)
                                            .padding(.top, 8)
                                            .padding(.bottom, 4)
                                        Spacer()
                                    }
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets())
                                    ForEach(sortedActiveTrips) { trip in
                                NavigationLink(destination: TripDetailView(trip: trip).environmentObject(store), tag: trip.id, selection: $selectedTripId) {
                                    TripCardView(trip: trip)
                                }
                                .listRowBackground(Color.clear)
                                        .swipeActions(edge: .trailing) {
                                            Button("Archive") {
                                                archiveActiveTrip(trip)
                                            }
                                            .tint(.primaryPink)
                                        }
                                    }
                                    .onDelete(perform: deleteActiveTrip)
                                    .onMove(perform: sortOption == .manual ? { indices, newOffset in
                                    store.trips.move(fromOffsets: indices, toOffset: newOffset)
                                    } : nil)
                                }
                            }
                            
                            if !sortedPastTrips.isEmpty {
                                Section {
                                    // Custom header that respects dark mode
                                    HStack {
                                        Text("Past Trips")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(darkMode ? .darkText : .black)
                                            .padding(.horizontal)
                                            .padding(.top, 8)
                                            .padding(.bottom, 4)
                                        Spacer()
                                    }
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets())
                                    ForEach(sortedPastTrips) { trip in
                                        NavigationLink(destination: TripDetailView(trip: trip).environmentObject(store), tag: trip.id, selection: $selectedTripId) {
                                            TripCardView(trip: trip)
                                        }
                                        .listRowBackground(Color.clear)
                                        .swipeActions(edge: .trailing) {
                                            Button("Delete") {
                                                deletePastTripById(trip.id)
                                            }
                                            .tint(.red)
                                        }
                                        .swipeActions(edge: .leading) {
                                            Button("Restore") {
                                                restorePastTrip(trip)
                                            }
                                            .tint(.primaryPink)
                                        }
                                    }
                                    .onDelete(perform: deletePastTrip)
                                }
                            }
                        }
                        .listStyle(PlainListStyle())
                        .background(darkMode ? Color.darkBackground : Color.white)
                        .modifier(ScrollContentBackgroundHidden())
                        .listRowBackground(Color.clear)
                        .listSectionSeparator(.hidden)
                        .environment(\.defaultMinListRowHeight, 0)
                        .safeAreaInset(edge: .bottom) {
                            Color.clear.frame(height: 100)
                    }
                    }
                    // Floating Add Button (bottom center with translucency)
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: { showingAddTrip = true }) {
                                HStack {
                                    Image(systemName: "plus")
                                        .font(.system(size: 18, weight: .bold))
                                    Text("Add Trip")
                                        .font(.system(size: 18, weight: .bold, design: .default))
                                }
                                .padding(.horizontal, 32)
                                .padding(.vertical, 16)
                                .background(
                                    Capsule()
                                        .fill(LinearGradient(gradient: Gradient(colors: [Color.primaryPink, Color.secondaryPink]), startPoint: .leading, endPoint: .trailing))
                                        .opacity(0.95)
                                )
                                .foregroundColor(.white)
                                .shadow(color: Color.primaryPink.opacity(0.4), radius: 12, x: 0, y: 6)
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .accessibilityLabel("Add Trip")
                            Spacer()
                        }
                        .padding(.bottom, 32)
                    }
                }
            }
            .sheet(isPresented: $showingAddTrip) {
                TripFormView(exchangeRateService: exchangeRateService, store: store) { name, budget, currency, icon, startDate, endDate in
                    store.addTrip(name: name, budget: budget, currency: currency, icon: icon, startDate: startDate, endDate: endDate)
                    if let newTrip = store.activeTrips.last {
                        selectedTripId = newTrip.id
                    }
                    showingAddTrip = false
                }
            }

            .sheet(isPresented: $showingSettings) {
                SettingsView(store: store)
            }
            .sheet(isPresented: $showingYearlyBudgetEdit) {
                YearlyBudgetEditView(store: store)
            }
        }
    }
}

struct YearlyBudgetView: View {
    @ObservedObject var store: TripStore
    @Binding var showingEdit: Bool
    @AppStorage("darkMode") private var darkMode = false
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .foregroundColor(.primaryPink)
                            .font(.system(size: 16, weight: .semibold))
                        Text("Yearly Vacation Budget")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(darkMode ? .darkText : .black)
                    }
                }
                Spacer()
                Button("Edit") {
                    showingEdit = true
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primaryPink)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.lightPink.opacity(0.2)))
                .shadow(color: .primaryPink.opacity(0.2), radius: 4, x: 0, y: 2)
            }
            
            if store.yearlyBudget > 0 {
                ProgressView(value: store.totalSpentThisYear, total: store.yearlyBudget > 0 ? store.yearlyBudget : 1)
                    .accentColor(store.totalSpentThisYear <= store.yearlyBudget ? .green : .red)
                    .frame(height: 8)
                    .clipShape(Capsule())
                    .background(Capsule().fill(Color.gray.opacity(0.2)))
                
                HStack {
                    Text("\(formatCurrency(store.totalSpentThisYear, currency: store.globalCurrency)) spent")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(darkMode ? .darkSecondaryText : .gray)
                    Spacer()
                    Text("\(formatCurrency(store.yearlyBudget - store.totalSpentThisYear, currency: store.globalCurrency)) left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primaryPink)
                }
                
                if isExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        Divider()
                        
                        HStack {
                            Text("This Year's Budget:")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(darkMode ? .darkText : .black)
                            Spacer()
                            Text(formatCurrency(store.yearlyBudget, currency: store.globalCurrency))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(darkMode ? .darkText : .black)
                        }
                        
                        HStack {
                            Text("Available for New Trips:")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(darkMode ? .darkText : .black)
                            Spacer()
                            Text(formatCurrency(store.yearlyBudget - store.totalExpectedThisYear, currency: store.globalCurrency))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primaryPink)
                        }
                        
                        HStack {
                            Text("Lifetime Savings:")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(darkMode ? .darkText : .black)
                            Spacer()
                            
                            if store.hasCompletedTrips {
                                Text(formatCurrency(store.lifetimeSavings, currency: store.globalCurrency))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(store.lifetimeSavings >= 0 ? .green : .red)
                            } else {
                                Text("Complete your first trip to unlock!")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .slide))
                }
            } else {
                Text("Set your yearly vacation budget to track spending across all trips")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(darkMode ? .darkSecondaryText : .gray)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 16).fill(darkMode ? Color.darkCard : Color.white))
        .shadow(color: darkMode ? Color.clear : Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(darkMode ? Color.gray.opacity(0.2) : Color.gray.opacity(0.08), lineWidth: 1)
        )
    }
}

struct YearlyBudgetEditView: View {
    @ObservedObject var store: TripStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("darkMode") private var darkMode = false
    @State private var budget: String = ""
    @State private var currentEncouragementMessage: String = ""
    
    private let encouragingMessages = [
        "You're already smarter than 70% of travelers by setting a budget",
        "Having a budget saves travelers 3-5 hours on average in planning alone"
    ]
    
    private func getRandomEncouragementMessage() -> String {
        return encouragingMessages.randomElement() ?? encouragingMessages[0]
    }
    
    var displayAmount: String {
        if budget.isEmpty {
            return "\(store.globalCurrency.symbol)0"
        }
        if let value = Double(budget) {
            return formatCurrency(value, currency: store.globalCurrency)
        }
        return "\(store.globalCurrency.symbol)\(budget)"
    }
    
    var body: some View {
        ZStack {
            (darkMode ? Color.darkBackground : Color.white).ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header with proper spacing
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.primaryPink)
                    Spacer()
                    Text("Yearly Budget")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(darkMode ? .darkText : .black)
                    Spacer()
                    Button("Cancel") {
                        dismiss()
                    }
                    .opacity(0) // Hidden but maintains spacing
                }
                .padding(.horizontal)
                .padding(.top, 40)
                
                // Large amount display with balanced spacing
                Text(displayAmount)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(darkMode ? .darkText : .black)
                    .padding(.vertical, 16)
                
                // Info text with proper spacing
                VStack(spacing: 8) {
                    Text("Set your yearly vacation budget")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(darkMode ? .darkText : .black)
                    Text("Track spending across all your trips for the year")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(darkMode ? .darkSecondaryText : .gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
                
                // Encouraging message card
                if let budgetValue = Double(budget), budgetValue > 0 && !currentEncouragementMessage.isEmpty {
                    Text(currentEncouragementMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(LinearGradient(gradient: Gradient(colors: [Color.primaryPink, Color.secondaryPink]), startPoint: .leading, endPoint: .trailing))
                        )
                        .padding(.horizontal)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity.combined(with: .slide))
                }
                
                Spacer()
                
                // Evenly spaced number pad
                VStack(spacing: 12) {
                    ForEach([["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], [".", "0", "←"]], id: \.self) { row in
                        HStack(spacing: 12) {
                            ForEach(row, id: \.self) { button in
                                Button(action: {
                                    if button == "←" {
                                        if !budget.isEmpty {
                                            budget.removeLast()
                                            // Clear encouragement message when budget is cleared
                                            if budget.isEmpty {
                                                currentEncouragementMessage = ""
                                            }
                                        }
                                    } else if button == "." {
                                        if !budget.contains(".") {
                                            if budget.isEmpty {
                                                budget = "0."
                                            } else {
                                                budget += button
                                            }
                                        }
                                    } else {
                                        if let decimalIndex = budget.firstIndex(of: ".") {
                                            let decimalPart = budget[budget.index(after: decimalIndex)...]
                                            if decimalPart.count < 2 {
                                                budget += button
                                            }
                                        } else {
                                            budget += button
                                        }
                                    }
                                    
                                    // Update encouragement message when valid budget is entered
                                    if let budgetValue = Double(budget), budgetValue > 0 {
                                        if currentEncouragementMessage.isEmpty {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                currentEncouragementMessage = getRandomEncouragementMessage()
                                            }
                                        }
                                    } else {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            currentEncouragementMessage = ""
                                        }
                                    }
                                }) {
                                    Text(button)
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundColor(darkMode ? .darkText : .black)
                                        .frame(width: 65, height: 65)
                                        .background(darkMode ? Color.darkCard : Color.gray.opacity(0.1))
                                        .clipShape(Circle())
                                }
                            }
                        }
                    }
                }
                
                Spacer(minLength: 8)
                
                // Save button with proper spacing
                Button(action: {
                    if let budgetValue = Double(budget) {
                        store.yearlyBudget = budgetValue
                        dismiss()
                    }
                }) {
                    Text("Save")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(gradient: Gradient(colors: [Color.primaryPink, Color.secondaryPink]), startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(16)
                        .shadow(color: Color.primaryPink.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .disabled(Double(budget) == nil)
                .opacity(Double(budget) == nil ? 0.6 : 1.0)
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            if store.yearlyBudget > 0 {
                // Format with appropriate decimal places for currency accuracy
                if store.yearlyBudget.truncatingRemainder(dividingBy: 1) == 0 {
                    budget = String(format: "%.0f", store.yearlyBudget)
                } else {
                    budget = String(format: "%.2f", store.yearlyBudget)
                }
            }
        }
    }
}

struct ScrollContentBackgroundHidden: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollContentBackground(.hidden)
        } else {
            content
        }
    }
}

struct TripDetailView: View {
    @EnvironmentObject var store: TripStore
    @Environment(\.presentationMode) var presentationMode
    @AppStorage("darkMode") private var darkMode = false
    @State var trip: Trip
    @State private var showingAddCategory = false
    @State private var editingCategory: ExpenseCategory? = nil
    @State private var showingAddExpense = false
    @State private var editingExpense: Expense? = nil
    @State private var showBudgetAlert = false
    @State private var budgetAlertMessage = ""
    @State private var showCategoryBudgetWarning = false
    @State private var pendingCategoryName = ""
    @State private var pendingCategoryAmount: Double = 0
    @State private var isEditingCategory = false
    @State private var editingCategoryId: UUID? = nil
    @State private var showingEditTrip = false
    @State private var showTripBudgetWarning = false
    @State private var pendingTripName = ""
    @State private var pendingTripBudget: Double = 0
    @State private var pendingTripCurrency: Currency = .usd
    @State private var pendingTripIcon = ""
    @State private var pendingTripStartDate: Date? = nil
    @State private var pendingTripEndDate: Date? = nil
    
    // Calculate totals
    var totalPlanned: Double { trip.budget }
    var totalActual: Double { trip.actualExpenses.reduce(0) { $0 + $1.amount } }
    var plannedSoFar: Double { trip.expectedCategories.reduce(0) { $0 + $1.plannedAmount } }
    
    func actualForCategory(_ category: ExpenseCategory) -> Double {
        trip.actualExpenses.filter { $0.categoryId == category.id }.reduce(0) { $0 + $1.amount }
    }
    
    func canAddCategory(amount: Double, editing: ExpenseCategory? = nil) -> Bool {
        let current = plannedSoFar - (editing?.plannedAmount ?? 0)
        return current + amount <= trip.budget
    }
    
    func calculateCategoryOverBudget(amount: Double, editing: ExpenseCategory? = nil) -> Double {
        let current = plannedSoFar - (editing?.plannedAmount ?? 0)
        let newTotal = current + amount
        return max(0, newTotal - trip.budget)
    }
    
    func savePendingCategory() {
        if isEditingCategory, let categoryId = editingCategoryId {
            // Edit existing category
            if let idx = trip.expectedCategories.firstIndex(where: { $0.id == categoryId }) {
                trip.expectedCategories[idx].name = pendingCategoryName
                trip.expectedCategories[idx].plannedAmount = pendingCategoryAmount
                store.updateTrip(trip)
            }
            editingCategory = nil
        } else {
            // Add new category
            let newCat = ExpenseCategory(id: UUID(), name: pendingCategoryName, plannedAmount: pendingCategoryAmount)
            trip.expectedCategories.append(newCat)
            store.updateTrip(trip)
            showingAddCategory = false
        }
        
        // Reset pending data
        pendingCategoryName = ""
        pendingCategoryAmount = 0
        isEditingCategory = false
        editingCategoryId = nil
    }
    
    func calculateTripYearlyBudgetOverage(newBudget: Double, newCurrency: Currency) -> Double {
        guard store.yearlyBudget > 0 else { return 0 }
        
        // Calculate current total excluding this trip
        let currentTotal = store.activeTrips.filter { $0.id != trip.id }.reduce(0) { total, otherTrip in
            return total + store.exchangeRateService.convertAmount(otherTrip.budget, from: otherTrip.currency, to: store.globalCurrency)
        }
        
        // Convert new budget to global currency
        let newBudgetInGlobalCurrency = store.exchangeRateService.convertAmount(newBudget, from: newCurrency, to: store.globalCurrency)
        
        let newTotal = currentTotal + newBudgetInGlobalCurrency
        return max(0, newTotal - store.yearlyBudget)
    }
    
    func savePendingTripEdit() {
        trip.name = pendingTripName
        trip.budget = pendingTripBudget
        trip.currency = pendingTripCurrency
        trip.icon = pendingTripIcon
        trip.startDate = pendingTripStartDate
        trip.endDate = pendingTripEndDate
        store.updateTrip(trip)
        showingEditTrip = false
        
        // Reset pending data
        pendingTripName = ""
        pendingTripBudget = 0
        pendingTripCurrency = .usd
        pendingTripIcon = ""
        pendingTripStartDate = nil
        pendingTripEndDate = nil
    }
    
    var tripBudgetPercentage: Double {
        guard store.yearlyBudget > 0 else { return 0 }
        // Convert trip budget to global currency for percentage calculation
        let tripBudgetInGlobalCurrency = store.exchangeRateService.convertAmount(trip.budget, from: trip.currency, to: store.globalCurrency)
        return (tripBudgetInGlobalCurrency / store.yearlyBudget) * 100
    }
    
    var categorySpendingMap: [UUID: Double] {
        var map: [UUID: Double] = [:]
        for category in trip.expectedCategories {
            map[category.id] = actualForCategory(category)
        }
        return map
    }
    
    func adjustedCategorySpending(excluding expense: Expense) -> [UUID: Double] {
        var map = categorySpendingMap
        if let currentSpent = map[expense.categoryId] {
            map[expense.categoryId] = currentSpent - expense.amount
        }
        return map
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header with back and edit buttons
                HStack {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Text("Back")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primaryPink)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.lightPink.opacity(0.2)))
                            .shadow(color: .primaryPink.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    Spacer()
                    Button(action: { showingEditTrip = true }) {
                        Text("Edit")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primaryPink)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.lightPink.opacity(0.2)))
                            .shadow(color: .primaryPink.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(.top, 60) // Add safe area padding to avoid iPhone island
                .padding(.horizontal, 4)
                
                // Trip title
                    Text(trip.name)
                    .font(.system(size: 32, weight: .bold, design: .default))
                    .foregroundColor(darkMode ? .darkText : .black)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 4)
                
                // Budget
                VStack(alignment: .leading, spacing: 4) {
                    Text("Budget: \(formatCurrency(trip.budget, currency: trip.currency))")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(darkMode ? .darkSecondaryText : .gray)
                    
                    if store.yearlyBudget > 0 {
                        Text("\(String(format: "%.1f", tripBudgetPercentage))% of your yearly budget")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primaryPink)
                    }
                }
                .padding(.horizontal, 4)
                
                // Overall Progress Bar
                VStack(alignment: .leading, spacing: 12) {
                    Text("Total Progress")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(darkMode ? .darkText : .black)
                    ProgressView(value: totalActual, total: totalPlanned > 0 ? totalPlanned : 1)
                        .accentColor(totalActual <= totalPlanned ? .green : .red)
                        .frame(height: 8)
                        .clipShape(Capsule())
                        .background(Capsule().fill(Color.gray.opacity(0.2)))
                    HStack {
                        Text("\(formatCurrency(totalActual, currency: trip.currency)) spent of \(formatCurrency(totalPlanned, currency: trip.currency)) planned")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(darkMode ? .darkSecondaryText : .gray)
                        Spacer()
                        Text("\(formatCurrency(totalPlanned - totalActual, currency: trip.currency)) left")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primaryPink)
                    }
                }
                .padding(.bottom, 8)
                
                // Expected Categories
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Expected Expenses")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(darkMode ? .darkText : .black)
                        Spacer()
                        Text("Total: \(formatCurrency(plannedSoFar, currency: trip.currency))")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primaryPink)
                    }
                    ForEach(trip.expectedCategories) { category in
                        CategoryCard(category: category, trip: $trip, onEdit: { editingCategory = category })
                    }
                    Button("Add Category") { showingAddCategory = true }
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primaryPink)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.lightPink.opacity(0.2)))
                        .shadow(color: .primaryPink.opacity(0.2), radius: 4, x: 0, y: 2)
                        .padding(.top, 8)
                }
                
                // Actual Expenses
                VStack(alignment: .leading, spacing: 12) {
                    Text("Actual Expenses")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(darkMode ? .darkText : .black)
                    ForEach(trip.actualExpenses) { expense in
                        ExpenseCard(expense: expense, trip: $trip, onEdit: { editingExpense = expense })
                    }
                    Button("Add Expense") { showingAddExpense = true }
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primaryPink)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.lightPink.opacity(0.2)))
                        .shadow(color: .primaryPink.opacity(0.2), radius: 4, x: 0, y: 2)
                        .padding(.top, 8)
                }
            }
            .padding()
        }
        .background(darkMode ? Color.darkBackground : Color.white)
        .ignoresSafeArea()
        .navigationBarHidden(true)
        .sheet(isPresented: $showingAddCategory) {
            CategoryFormView(trip: trip, tripBudget: trip.budget, currentPlannedTotal: plannedSoFar) { name, amount in
                pendingCategoryName = name
                pendingCategoryAmount = amount
                isEditingCategory = false
                
                let overBudget = calculateCategoryOverBudget(amount: amount)
                if overBudget > 0 {
                    showCategoryBudgetWarning = true
                } else {
                    savePendingCategory()
                }
            }
        }
        .sheet(item: $editingCategory) { category in
            CategoryFormView(category: category, trip: trip, tripBudget: trip.budget, currentPlannedTotal: plannedSoFar - category.plannedAmount) { name, amount in
                pendingCategoryName = name
                pendingCategoryAmount = amount
                isEditingCategory = true
                editingCategoryId = category.id
                
                let overBudget = calculateCategoryOverBudget(amount: amount, editing: category)
                if overBudget > 0 {
                    showCategoryBudgetWarning = true
                } else {
                    savePendingCategory()
                }
            }
        }
        .sheet(isPresented: $showingAddExpense) {
            ExpenseFormView(trip: trip, categories: trip.expectedCategories, categorySpending: categorySpendingMap) { catId, amount, desc in
                let newExp = Expense(id: UUID(), categoryId: catId, amount: amount, description: desc, date: Date())
                trip.actualExpenses.append(newExp)
                store.updateTrip(trip)
                showingAddExpense = false
            }
        }
        .sheet(item: $editingExpense) { expense in
            ExpenseFormView(expense: expense, trip: trip, categories: trip.expectedCategories, categorySpending: adjustedCategorySpending(excluding: expense)) { catId, amount, desc in
                if let idx = trip.actualExpenses.firstIndex(where: { $0.id == expense.id }) {
                    trip.actualExpenses[idx].categoryId = catId
                    trip.actualExpenses[idx].amount = amount
                    trip.actualExpenses[idx].description = desc
                    trip.actualExpenses[idx].date = Date()
                    store.updateTrip(trip)
                }
                editingExpense = nil
            }
        }
        .alert(isPresented: $showBudgetAlert) {
            Alert(title: Text("Budget Limit Exceeded"), message: Text(budgetAlertMessage), dismissButton: .default(Text("OK")))
        }
        .alert("Budget Warning", isPresented: $showCategoryBudgetWarning) {
            Button("Cancel", role: .cancel) {
                // Reset pending data
                pendingCategoryName = ""
                pendingCategoryAmount = 0
                isEditingCategory = false
                editingCategoryId = nil
            }
            Button("Continue Anyway") {
                savePendingCategory()
            }
        } message: {
            let overBudget = calculateCategoryOverBudget(amount: pendingCategoryAmount, editing: isEditingCategory ? trip.expectedCategories.first(where: { $0.id == editingCategoryId }) : nil)
            Text("This would put you \(formatCurrency(overBudget, currency: trip.currency)) over your trip budget. Continue anyway?")
        }
        .sheet(isPresented: $showingEditTrip) {
            TripFormView(trip: trip, exchangeRateService: store.exchangeRateService, store: store) { name, budget, currency, icon, startDate, endDate in
                trip.name = name
                trip.budget = budget
                trip.currency = currency
                trip.icon = icon
                trip.startDate = startDate
                trip.endDate = endDate
                store.updateTrip(trip)
                showingEditTrip = false
            }
        }

    }
}

struct TripCardView: View {
    let trip: Trip
    @AppStorage("darkMode") private var darkMode = false
    var spent: Double { trip.actualExpenses.reduce(0) { $0 + $1.amount } }
    var left: Double { trip.budget - spent }
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            infoView
            Spacer()
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 16).fill(darkMode ? Color.darkCard : Color.white))
        .shadow(color: darkMode ? Color.clear : Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(darkMode ? Color.gray.opacity(0.2) : Color.gray.opacity(0.08), lineWidth: 1)
        )
    }
    private var tripIcon: some View {
        Text(trip.icon)
            .font(.system(size: 36))
            .frame(width: 64, height: 64)
    }
    
    private var infoView: some View {
        HStack(spacing: 16) {
            tripIcon
            
            VStack(alignment: .leading, spacing: 8) {
            Text(trip.name)
                    .font(.system(size: 24, weight: .bold, design: .default))
                    .foregroundColor(darkMode ? .darkText : .black)
                    .lineLimit(2)
            if let start = trip.startDate, let end = trip.endDate {
                Text("\(dateFormatter.string(from: start)) - \(dateFormatter.string(from: end))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(darkMode ? .darkSecondaryText : .gray)
            }
            summaryView
            progressBar
            }
        }
    }
    private var summaryView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(formatCurrency(spent, currency: trip.currency))
                    .font(.system(size: 20, weight: .bold, design: .default))
                    .foregroundColor(darkMode ? .darkText : .black)
                Text("spent")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(darkMode ? .darkSecondaryText : .gray)
                Spacer()
            }
            HStack {
                Text(formatCurrency(left, currency: trip.currency))
                    .font(.system(size: 20, weight: .bold, design: .default))
                    .foregroundColor(left < 0 ? .red : .primaryPink)
                Text("left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(darkMode ? .darkSecondaryText : .gray)
                Spacer()
            }
        }
    }
    private var progressBar: some View {
        ProgressView(value: spent, total: trip.budget > 0 ? trip.budget : 1)
            .accentColor(spent <= trip.budget ? .green : .red)
            .frame(height: 8)
            .clipShape(Capsule())
            .background(Capsule().fill(Color.gray.opacity(0.2)))
    }
}

struct TripFormView: View {
    var trip: Trip? = nil
    var exchangeRateService: ExchangeRateService
    var store: TripStore? = nil
    var onSave: (String, Double, Currency, String, Date?, Date?) -> Void
    @Environment(\.dismiss) private var dismiss
    @AppStorage("darkMode") private var darkMode = false
    @State private var name: String = ""
    @State private var budget: String = ""
    @State private var selectedCurrency: Currency = .usd
    @State private var selectedIcon: String = "✈️"
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var showDatePicker = false
    @State private var showingIconPicker = false
    @State private var dateSelectionStep: DateSelectionStep = .start
    @State private var lastSelectedDate: Date = Date()
    @State private var hasSelectedDates = false
    @State private var showBudgetWarning = false
    @State private var budgetWarningAmount: Double = 0
    
    enum DateSelectionStep {
        case start, end, complete
    }
    
    private let availableIcons = ["✈️", "🚗", "🏖️", "🏔️", "🌴", "🚢", "🏕️", "🏝️", "🌊", "🏜️", "🏞️", "⛰️", "🌋", "🗻", "🏰", "🏛️", "🍻", "⛳", "🐬", "🎿", "🏄", "🚁", "🎢", "🎡"]
    
    var displayAmount: String {
        if budget.isEmpty {
            return "\(selectedCurrency.symbol)0"
        }
        if let value = Double(budget) {
            // Use formatCurrency function which already includes the symbol
            return formatCurrency(value, currency: selectedCurrency)
        }
        return "\(selectedCurrency.symbol)\(budget)"
    }
    
    var dateRangeDisplay: String {
        if hasSelectedDates {
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d/yy" // Shorter format to fit on one line
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        }
        return ""
    }
    
    func calculateYearlyBudgetOverage() -> Double {
        guard let store = store, store.yearlyBudget > 0, let budgetValue = Double(budget) else { return 0 }
        
        // Calculate current total of expected trip budgets excluding the trip being edited
        let currentExpectedTotal = store.activeTrips.filter { activeTrip in
            if let editingTrip = trip {
                return activeTrip.id != editingTrip.id
            }
            return true
        }.reduce(0) { total, activeTrip in
            // Convert trip budget to global currency for comparison
            return total + store.exchangeRateService.convertAmount(activeTrip.budget, from: activeTrip.currency, to: store.globalCurrency)
        }
        
        // Convert new trip budget to global currency
        let newBudgetInGlobalCurrency = store.exchangeRateService.convertAmount(budgetValue, from: selectedCurrency, to: store.globalCurrency)
        
        let newExpectedTotal = currentExpectedTotal + newBudgetInGlobalCurrency
        return max(0, newExpectedTotal - store.yearlyBudget)
    }
    
    var body: some View {
        ZStack {
            (darkMode ? Color.darkBackground : Color.white).ignoresSafeArea()
            
            VStack(spacing: 12) {
                // Header with compact spacing
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.primaryPink)
                    Spacer()
                    Text(trip == nil ? "Add Trip" : "Edit Trip")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(darkMode ? .darkText : .black)
                    Spacer()
                    Button("Cancel") {
                        dismiss()
                    }
                    .opacity(0) // Hidden but maintains spacing
                }
                .padding(.horizontal)
                .padding(.top, 50) // Reduced top padding
                
                // Compact amount display
                Text(displayAmount)
                    .font(.system(size: 36, weight: .bold)) // Smaller for better fit
                    .foregroundColor(darkMode ? .darkText : .black)
                    .padding(.vertical, 4)
                    
                                    // Form fields with consistent spacing
                VStack(spacing: 12) {
                    // Combined Trip icon and name field
                    HStack {
                        // Trip Icon with change indicator
                        Button(action: { showingIconPicker = true }) {
                            ZStack {
                                Text(selectedIcon)
                                    .font(.system(size: 24))
                                    .frame(width: 40, height: 40)
                                    .background(Color.lightPink.opacity(0.2))
                                    .cornerRadius(8)
                                
                                // Small plus indicator to show it's tappable
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.primaryPink)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .offset(x: 12, y: -12)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Trip Name")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(darkMode ? .darkSecondaryText : .gray)
                            TextField("Enter trip name", text: $name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(darkMode ? .darkText : .black)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(darkMode ? Color.darkCard : Color.gray.opacity(0.05))
                    .cornerRadius(10)
                    
                    // Currency picker
                    Menu {
                        ForEach(Currency.allCases) { currency in
                            Button(action: { 
                                let oldCurrency = selectedCurrency
                                selectedCurrency = currency
                                
                                // Convert existing budget amount when currency changes
                                if let budgetValue = Double(budget), budgetValue > 0 {
                                    Task { @MainActor in
                                        await exchangeRateService.fetchExchangeRates()
                                        let convertedAmount = exchangeRateService.convertAmount(budgetValue, from: oldCurrency, to: currency)
                                        // Format with appropriate decimal places for currency accuracy
                                        if convertedAmount.truncatingRemainder(dividingBy: 1) == 0 {
                                            budget = String(format: "%.0f", convertedAmount)
                                        } else {
                                            budget = String(format: "%.2f", convertedAmount)
                                        }
                                    }
                                } else {
                                    // Fetch new exchange rates when currency changes
                                    Task { @MainActor in
                                        await exchangeRateService.fetchExchangeRates()
                                    }
                                }
                            }) {
                                HStack {
                                    Text("\(currency.symbol) - \(currency.name)")
                                    Spacer()
                                    if selectedCurrency == currency {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.primaryPink)
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "dollarsign.circle")
                                .foregroundColor(.primaryPink)
                                .frame(width: 20, height: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Currency")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(darkMode ? .darkSecondaryText : .gray)
                                Text("\(selectedCurrency.symbol) - \(selectedCurrency.name)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(darkMode ? .darkText : .black)
                            }
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(darkMode ? .darkSecondaryText : .gray)
                                .font(.system(size: 12))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(darkMode ? Color.darkCard : Color.gray.opacity(0.05))
                        .cornerRadius(10)
                    }
                    
                    // Dates section - Fixed toggle behavior
                    VStack(spacing: 0) {
                        HStack {
                            Text("Add Dates")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(darkMode ? .darkText : .black)
                            Spacer()
                            if !dateRangeDisplay.isEmpty {
                                Text(dateRangeDisplay)
                                    .font(.system(size: 11, weight: .medium)) // Smaller font to fit better
                                    .foregroundColor(.primaryPink)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.lightPink.opacity(0.2))
                                    .cornerRadius(6)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8) // Allow text to scale down if needed
                                    .onTapGesture {
                                        // Tap pink dates to reopen calendar
                                        showDatePicker = true
                                        dateSelectionStep = .start
                                    }
                            }
                            Toggle("", isOn: $hasSelectedDates)
                                .toggleStyle(SwitchToggleStyle(tint: .primaryPink))
                                .onChange(of: hasSelectedDates) { isOn in
                                    if isOn {
                                        // When turned ON, show calendar if no dates selected
                                        if dateRangeDisplay.isEmpty {
                                            showDatePicker = true
                                            dateSelectionStep = .start
                                            lastSelectedDate = startDate
                                            // Ensure endDate is not the same as startDate initially
                                            if endDate == startDate {
                                                endDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate) ?? startDate
                                            }
                                        }
                                    } else {
                                        // When turned OFF, clear dates and hide calendar
                                        showDatePicker = false
                                        // Reset dates without triggering onChange
                                        DispatchQueue.main.async {
                                            startDate = Date()
                                            endDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                                            lastSelectedDate = Date()
                                        }
                                    }
                                }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(darkMode ? Color.darkCard : Color.gray.opacity(0.05))
                        .cornerRadius(10)
                        
                        if showDatePicker {
                            VStack(spacing: 8) {
                                HStack {
                                    Text(dateSelectionStep == .start ? "Select start date" : dateSelectionStep == .end ? "Select end date" : "Dates selected")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(dateSelectionStep == .complete ? .primaryPink : .white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            dateSelectionStep != .complete
                                            ? LinearGradient(gradient: Gradient(colors: [Color.primaryPink, Color.secondaryPink]), startPoint: .leading, endPoint: .trailing)
                                            : LinearGradient(gradient: Gradient(colors: [Color.clear]), startPoint: .leading, endPoint: .trailing)
                                        )
                                        .cornerRadius(8)
                                        .shadow(color: dateSelectionStep != .complete ? Color.primaryPink.opacity(0.4) : Color.clear, radius: 4, x: 0, y: 2)
                                    
                                    Spacer()
                                    Button("Done") {
                                        showDatePicker = false
                                        // Keep toggle ON when dates are selected
                                        if dateSelectionStep == .complete {
                                            hasSelectedDates = true
                                        }
                                    }
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(dateSelectionStep == .complete ? .white : .primaryPink)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        dateSelectionStep == .complete 
                                        ? LinearGradient(gradient: Gradient(colors: [Color.primaryPink, Color.secondaryPink]), startPoint: .leading, endPoint: .trailing)
                                        : LinearGradient(gradient: Gradient(colors: [Color.clear]), startPoint: .leading, endPoint: .trailing)
                                    )
                                    .cornerRadius(8)
                                    .shadow(color: dateSelectionStep == .complete ? Color.primaryPink.opacity(0.4) : Color.clear, radius: 4, x: 0, y: 2)
                                }
                                
                                DatePicker("", selection: $lastSelectedDate, displayedComponents: .date)
                                    .datePickerStyle(GraphicalDatePickerStyle())
                                    .accentColor(.primaryPink)
                                    .onChange(of: lastSelectedDate) { newSelectedDate in
                                        DispatchQueue.main.async {
                                            if dateSelectionStep == .start {
                                                // First tap: set start date
                                                startDate = newSelectedDate
                                                // If end date is before start date, adjust it
                                                if endDate < newSelectedDate {
                                                    endDate = Calendar.current.date(byAdding: .day, value: 1, to: newSelectedDate) ?? newSelectedDate
                                                }
                                                dateSelectionStep = .end
                                            } else if dateSelectionStep == .end {
                                                // Second tap: set end date
                                                if newSelectedDate >= startDate {
                                                    endDate = newSelectedDate
                                                    dateSelectionStep = .complete
                                                    hasSelectedDates = true
                                                } else {
                                                    // If user picks a date before start, make it the new start date
                                                    startDate = newSelectedDate
                                                    dateSelectionStep = .end
                                                }
                                            } else if dateSelectionStep == .complete {
                                                // Third tap: restart - this becomes new start date
                                                startDate = newSelectedDate
                                                // Reset end date to be after start date
                                                endDate = Calendar.current.date(byAdding: .day, value: 1, to: newSelectedDate) ?? newSelectedDate
                                                dateSelectionStep = .end
                                            }
                                        }
                                    }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                            .background(darkMode ? Color.darkCard : Color.gray.opacity(0.05))
                        }
                    }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Evenly spaced number pad
                    VStack(spacing: 16) {
                        ForEach([["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], [".", "0", "←"]], id: \.self) { row in
                            HStack(spacing: 16) {
                                ForEach(row, id: \.self) { button in
                                    Button(action: {
                                        if button == "←" {
                                            if !budget.isEmpty {
                                                budget.removeLast()
                                            }
                                        } else if button == "." {
                                            if !budget.contains(".") {
                                                if budget.isEmpty {
                                                    budget = "0."
                                                } else {
                                                    budget += button
                                                }
                                            }
                                        } else {
                                            // Check if we already have a decimal point and 2 digits after it
                                            if let decimalIndex = budget.firstIndex(of: ".") {
                                                let decimalPart = budget[budget.index(after: decimalIndex)...]
                                                if decimalPart.count < 2 {
                                                    budget += button
                                                }
                                            } else {
                                                budget += button
                                            }
                                        }
                                    }) {
                                        Text(button)
                                            .font(.system(size: 26, weight: .medium))
                                            .foregroundColor(darkMode ? .darkText : .black)
                                            .frame(width: 70, height: 70)
                                            .background(darkMode ? Color.darkCard : Color.gray.opacity(0.1))
                                            .clipShape(Circle())
                                    }
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Compact continue button
                    Button(action: {
                    // Only hide calendar when continue is pressed
                    if showDatePicker {
                        showDatePicker = false
                        // Keep toggle ON when dates are selected
                        if dateSelectionStep == .complete {
                            hasSelectedDates = true
                        }
                    }
                    
                        if let budgetValue = Double(budget) {
                        // Check for yearly budget overage
                        let overage = calculateYearlyBudgetOverage()
                        if overage > 0 {
                            budgetWarningAmount = overage
                            showBudgetWarning = true
                        } else {
                            onSave(name, budgetValue, selectedCurrency, selectedIcon, hasSelectedDates ? startDate : nil, hasSelectedDates ? endDate : nil)
                            dismiss()
                        }
                    }
                }) {
                    Text("Continue")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(gradient: Gradient(colors: [Color.primaryPink, Color.secondaryPink]), startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(16)
                        .shadow(color: Color.primaryPink.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                    .disabled(name.isEmpty || Double(budget) == nil)
                    .opacity((name.isEmpty || Double(budget) == nil) ? 0.6 : 1.0)
                    .padding(.horizontal)
                    .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $showingIconPicker) {
            IconPickerView(selectedIcon: $selectedIcon)
        }
        .overlay(
            // Budget warning overlay
            Group {
                if showBudgetWarning {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .onTapGesture {
                                showBudgetWarning = false
                            }
                        
                        VStack(spacing: 16) {
                            Text("Yearly Budget Warning")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(darkMode ? .darkText : .black)
                            
                            Text("This would put you \(formatCurrency(budgetWarningAmount, currency: store?.globalCurrency ?? .usd)) over your yearly vacation budget. Continue anyway?")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(darkMode ? .darkSecondaryText : .gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            HStack(spacing: 12) {
                                Button("Cancel") {
                                    showBudgetWarning = false
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primaryPink)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.primaryPink, lineWidth: 2)
                                )
                                
                                Button("Continue Anyway") {
                                    showBudgetWarning = false
                                    if let budgetValue = Double(budget) {
                                        onSave(name, budgetValue, selectedCurrency, selectedIcon, hasSelectedDates ? startDate : nil, hasSelectedDates ? endDate : nil)
                                        dismiss()
                                    }
                                }
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(gradient: Gradient(colors: [Color.primaryPink, Color.secondaryPink]), startPoint: .leading, endPoint: .trailing)
                                )
                                .cornerRadius(8)
                            }
                            .padding(.horizontal)
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(darkMode ? Color.darkCard : Color.white)
                                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                        )
                        .padding(.horizontal, 32)
                    }
                    .animation(.easeInOut(duration: 0.3), value: showBudgetWarning)
                }
            }
        )
        .onAppear {
            if let trip = trip {
                name = trip.name
                // Format with appropriate decimal places for currency accuracy
                if trip.budget.truncatingRemainder(dividingBy: 1) == 0 {
                    budget = String(format: "%.0f", trip.budget)
                } else {
                    budget = String(format: "%.2f", trip.budget)
                }
                selectedCurrency = trip.currency
                selectedIcon = trip.icon
                startDate = trip.startDate ?? Date()
                endDate = trip.endDate ?? Date()
                lastSelectedDate = trip.startDate ?? Date()
                hasSelectedDates = trip.startDate != nil
            } else {
                lastSelectedDate = startDate
            }
            
            // Fetch exchange rates when view appears
            Task { @MainActor in
                await exchangeRateService.fetchExchangeRates()
            }
        }
    }
}

struct IconPickerView: View {
    @Binding var selectedIcon: String
    @Environment(\.dismiss) private var dismiss
    @AppStorage("darkMode") private var darkMode = false
    
    private let availableIcons = ["✈️", "🚗", "🏖️", "🏔️", "🌴", "🚢", "🏕️", "🏝️", "🌊", "🏜️", "🏞️", "⛰️", "🌋", "🗻", "🏰", "🏛️", "🍻", "⛳", "🐬", "🎿", "🏄", "🚁", "🎢", "🎡"]
    
    var body: some View {
        NavigationView {
            ZStack {
                (darkMode ? Color.darkBackground : Color.white).ignoresSafeArea()
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 16) {
                    ForEach(availableIcons, id: \.self) { icon in
                        Button(action: {
                            selectedIcon = icon
                            dismiss()
                        }) {
                            Text(icon)
                                .font(.system(size: 32))
                                .frame(width: 60, height: 60)
                                .background(
                                    Circle()
                                        .fill(selectedIcon == icon ? Color.primaryPink.opacity(0.2) : (darkMode ? Color.darkCard : Color.gray.opacity(0.1)))
                                )
                                .overlay(
                                    Circle()
                                        .stroke(selectedIcon == icon ? Color.primaryPink : Color.clear, lineWidth: 2)
                                )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.primaryPink)
                }
            }
        }
    }
}



struct CategoryFormView: View {
    var category: ExpenseCategory? = nil
    var trip: Trip
    var tripBudget: Double = 0
    var currentPlannedTotal: Double = 0
    var onSave: (String, Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @AppStorage("darkMode") private var darkMode = false
    @State private var name: String = ""
    @State private var amount: String = ""
    @State private var selectedPresetCategory: String = ""
    @State private var showingCustomInput = false
    
    private let presetCategories = [
        "Flights",
        "Hotel/Airbnb", 
        "Food/Entertainment",
        "Ground Transportation",
        "Custom"
    ]
    
    var smartMessage: String {
        guard let amountValue = Double(amount), amountValue > 0 else { return "" }
        let remaining = tripBudget - currentPlannedTotal
        let percentage = (amountValue / tripBudget) * 100
        
        if percentage < 10 {
            return "💚 Small allocation - leaves plenty for other categories"
        } else if percentage < 25 {
            return "👍 Good balance - about \(Int(percentage))% of your total budget"
        } else if percentage < 50 {
            return "⚡ Major category - this is about \(Int(percentage))% of your budget"
        } else if amountValue <= remaining {
            return "🎯 Big allocation - make sure this covers everything you need"
        } else {
            return "⚠️ This would exceed your remaining budget of \(formatCurrency(remaining, currency: trip.currency))"
        }
    }
    
    var displayAmount: String {
        if amount.isEmpty {
            return "\(trip.currency.symbol)0"
        }
        if let value = Double(amount) {
            return formatCurrency(value, currency: trip.currency)
        }
        return "\(trip.currency.symbol)\(amount)"
    }
    
    var body: some View {
        ZStack {
            (darkMode ? Color.darkBackground : Color.white).ignoresSafeArea()
            
            VStack(spacing: 12) {
                // Header
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.primaryPink)
                    Spacer()
                    Text(category == nil ? "Add Category" : "Edit Category")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(darkMode ? .darkText : .black)
                    Spacer()
                    Button("Cancel") {
                        dismiss()
                    }
                    .opacity(0) // Hidden but maintains spacing
                }
                .padding(.horizontal)
                .padding(.top, 50)
                
                // Large amount display
                Text(displayAmount)
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(darkMode ? .darkText : .black)
                    .padding(.vertical, 8)
                
                // Form fields
                VStack(spacing: 12) {
                    // Category name picker/field
                    if showingCustomInput {
                        // Custom text input
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.primaryPink)
                                .frame(width: 20, height: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Category Name")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(darkMode ? .darkSecondaryText : .gray)
                                TextField("Enter custom category name", text: $name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(darkMode ? .darkText : .black)
                            }
                            
                            Button("Back") {
                                showingCustomInput = false
                                name = ""
                                selectedPresetCategory = ""
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primaryPink)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(darkMode ? Color.darkCard : Color.gray.opacity(0.05))
                        .cornerRadius(10)
                    } else {
                        // Category picker
                        Menu {
                            ForEach(presetCategories, id: \.self) { categoryOption in
                                Button(action: {
                                    if categoryOption == "Custom" {
                                        showingCustomInput = true
                                        selectedPresetCategory = ""
                                        name = ""
                                    } else {
                                        selectedPresetCategory = categoryOption
                                        name = categoryOption
                                        showingCustomInput = false
                                    }
                                }) {
                                    HStack {
                                        Text(categoryOption)
                                        if categoryOption == "Custom" {
                                            Spacer()
                                            Image(systemName: "pencil")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.primaryPink)
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(.primaryPink)
                                    .frame(width: 20, height: 20)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Category Name")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(darkMode ? .darkSecondaryText : .gray)
                                    Text(selectedPresetCategory.isEmpty ? "Select category" : selectedPresetCategory)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(selectedPresetCategory.isEmpty ? (darkMode ? .darkSecondaryText : .gray) : (darkMode ? .darkText : .black))
                                }
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(darkMode ? .darkSecondaryText : .gray)
                                    .font(.system(size: 12))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(darkMode ? Color.darkCard : Color.gray.opacity(0.05))
                            .cornerRadius(10)
                        }
                    }
                    
                    if !smartMessage.isEmpty {
                        Text(smartMessage)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(darkMode ? .darkSecondaryText : .gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .lineLimit(2)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Evenly spaced number pad
                VStack(spacing: 16) {
                    ForEach([["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], [".", "0", "←"]], id: \.self) { row in
                        HStack(spacing: 16) {
                            ForEach(row, id: \.self) { button in
                                Button(action: {
                                    if button == "←" {
                                        if !amount.isEmpty {
                                            amount.removeLast()
                                        }
                                    } else if button == "." {
                                        if !amount.contains(".") {
                                            if amount.isEmpty {
                                                amount = "0."
                                            } else {
                                                amount += button
                                            }
                                        }
                                    } else {
                                        // Check if we already have a decimal point and 2 digits after it
                                        if let decimalIndex = amount.firstIndex(of: ".") {
                                            let decimalPart = amount[amount.index(after: decimalIndex)...]
                                            if decimalPart.count < 2 {
                                                amount += button
                                            }
                                        } else {
                                            amount += button
                                        }
                                    }
                                }) {
                                    Text(button)
                                        .font(.system(size: 26, weight: .medium))
                                        .foregroundColor(darkMode ? .darkText : .black)
                                        .frame(width: 70, height: 70)
                                        .background(darkMode ? Color.darkCard : Color.gray.opacity(0.1))
                                        .clipShape(Circle())
                                }
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Continue button
                Button(action: {
                        if let amt = Double(amount) {
                            onSave(name, amt)
                            dismiss()
                        }
                }) {
                    Text("Continue")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(gradient: Gradient(colors: [Color.primaryPink, Color.secondaryPink]), startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(16)
                        .shadow(color: Color.primaryPink.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .disabled((showingCustomInput ? name.isEmpty : selectedPresetCategory.isEmpty) || Double(amount) == nil)
                .opacity(((showingCustomInput ? name.isEmpty : selectedPresetCategory.isEmpty) || Double(amount) == nil) ? 0.6 : 1.0)
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            if let category = category {
                name = category.name
                
                // Check if the existing category matches a preset
                if presetCategories.contains(category.name) && category.name != "Custom" {
                    selectedPresetCategory = category.name
                    showingCustomInput = false
                } else {
                    // It's a custom category
                    selectedPresetCategory = ""
                    showingCustomInput = true
                }
                
                // Format with appropriate decimal places for currency accuracy
                if category.plannedAmount.truncatingRemainder(dividingBy: 1) == 0 {
                    amount = String(format: "%.0f", category.plannedAmount)
                } else {
                    amount = String(format: "%.2f", category.plannedAmount)
                }
            }
        }
    }
}

struct ExpenseFormView: View {
    var expense: Expense? = nil
    var trip: Trip
    var categories: [ExpenseCategory]
    var categorySpending: [UUID: Double] = [:]
    var onSave: (UUID, Double, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @AppStorage("darkMode") private var darkMode = false
    @State private var selectedCategory: UUID? = nil
    @State private var amount: String = ""
    @State private var desc: String = ""
    
    var smartMessage: String {
        guard let amountValue = Double(amount), amountValue > 0,
              let categoryId = selectedCategory,
              let category = categories.first(where: { $0.id == categoryId }) else { return "" }
        
        let currentSpent = categorySpending[categoryId] ?? 0
        let newTotal = currentSpent + amountValue
        let remaining = category.plannedAmount - newTotal
        
        if newTotal <= category.plannedAmount * 0.5 {
            return "💚 Great! You'll have \(formatCurrency(remaining, currency: trip.currency)) left in \(category.name)"
        } else if newTotal <= category.plannedAmount * 0.8 {
            return "👍 On track - \(formatCurrency(remaining, currency: trip.currency)) remaining for \(category.name)"
        } else if newTotal <= category.plannedAmount {
            return "⚡ Getting close - \(formatCurrency(remaining, currency: trip.currency)) left for \(category.name)"
        } else {
            return "⚠️ This would put you \(formatCurrency(abs(remaining), currency: trip.currency)) over budget for \(category.name)"
        }
    }
    
    var displayAmount: String {
        if amount.isEmpty {
            return "\(trip.currency.symbol)0"
        }
        if let value = Double(amount) {
            return formatCurrency(value, currency: trip.currency)
        }
        return "\(trip.currency.symbol)\(amount)"
    }
    
    var selectedCategoryName: String {
        if let categoryId = selectedCategory,
           let category = categories.first(where: { $0.id == categoryId }) {
            return category.name
        }
        return "Select Category"
    }
    
    var body: some View {
        ZStack {
            (darkMode ? Color.darkBackground : Color.white).ignoresSafeArea()
            
            VStack(spacing: 12) {
                // Header
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.primaryPink)
                    Spacer()
                    Text(expense == nil ? "Add Expense" : "Edit Expense")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(darkMode ? .darkText : .black)
                    Spacer()
                    Button("Cancel") {
                        dismiss()
                    }
                    .opacity(0) // Hidden but maintains spacing
                }
                .padding(.horizontal)
                .padding(.top, 50)
                
                // Large amount display
                Text(displayAmount)
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(darkMode ? .darkText : .black)
                    .padding(.vertical, 8)
                
                // Form fields
                VStack(spacing: 12) {
                    // Category picker
                    Menu {
                    ForEach(categories) { cat in
                            Button(cat.name) {
                                selectedCategory = cat.id
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.primaryPink)
                                .frame(width: 20, height: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Category")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(darkMode ? .darkSecondaryText : .gray)
                                Text(selectedCategoryName)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(selectedCategory == nil ? (darkMode ? .darkSecondaryText : .gray) : (darkMode ? .darkText : .black))
                            }
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(darkMode ? .darkSecondaryText : .gray)
                                .font(.system(size: 12))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(darkMode ? Color.darkCard : Color.gray.opacity(0.05))
                        .cornerRadius(10)
                    }
                    
                    // Description field
                    HStack {
                        Image(systemName: "text.alignleft")
                            .foregroundColor(.primaryPink)
                            .frame(width: 20, height: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Description")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(darkMode ? .darkSecondaryText : .gray)
                            TextField("What did you buy?", text: $desc)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(darkMode ? .darkText : .black)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(darkMode ? Color.darkCard : Color.gray.opacity(0.05))
                    .cornerRadius(10)
                    
                    if !smartMessage.isEmpty {
                        Text(smartMessage)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(darkMode ? .darkSecondaryText : .gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .lineLimit(2)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Evenly spaced number pad
                VStack(spacing: 16) {
                    ForEach([["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], [".", "0", "←"]], id: \.self) { row in
                        HStack(spacing: 16) {
                            ForEach(row, id: \.self) { button in
                                Button(action: {
                                    if button == "←" {
                                        if !amount.isEmpty {
                                            amount.removeLast()
                                        }
                                    } else if button == "." {
                                        if !amount.contains(".") {
                                            if amount.isEmpty {
                                                amount = "0."
                                            } else {
                                                amount += button
                                            }
                                        }
                                    } else {
                                        // Check if we already have a decimal point and 2 digits after it
                                        if let decimalIndex = amount.firstIndex(of: ".") {
                                            let decimalPart = amount[amount.index(after: decimalIndex)...]
                                            if decimalPart.count < 2 {
                                                amount += button
                                            }
                                        } else {
                                            amount += button
                                        }
                                    }
                                }) {
                                    Text(button)
                                        .font(.system(size: 26, weight: .medium))
                                        .foregroundColor(darkMode ? .darkText : .black)
                                        .frame(width: 70, height: 70)
                                        .background(darkMode ? Color.darkCard : Color.gray.opacity(0.1))
                                        .clipShape(Circle())
                                }
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Continue button
                Button(action: {
                        if let catId = selectedCategory, let amt = Double(amount) {
                            onSave(catId, amt, desc)
                            dismiss()
                        }
                }) {
                    Text("Continue")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(gradient: Gradient(colors: [Color.primaryPink, Color.secondaryPink]), startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(16)
                        .shadow(color: Color.primaryPink.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .disabled(selectedCategory == nil || Double(amount) == nil)
                .opacity((selectedCategory == nil || Double(amount) == nil) ? 0.6 : 1.0)
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            if let expense = expense {
                selectedCategory = expense.categoryId
                // Format with appropriate decimal places for currency accuracy
                if expense.amount.truncatingRemainder(dividingBy: 1) == 0 {
                    amount = String(format: "%.0f", expense.amount)
                } else {
                    amount = String(format: "%.2f", expense.amount)
                }
                desc = expense.description
            }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var store: TripStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("darkMode") private var darkMode = false
    @State private var showingRecoveryAlert = false
    @State private var recoveryMessage = ""
    

    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Appearance")) {
                    Toggle("Dark Mode", isOn: $darkMode)
                }
                
                Section(header: Text("Currency")) {
                    Picker("Default Currency", selection: $store.globalCurrency) {
                        ForEach(Currency.allCases) { currency in
                            Text("\(currency.symbol) - \(currency.name)")
                                .tag(currency)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: store.globalCurrency) { newCurrency in
                        // Convert all existing trip data to new currency
                        Task { @MainActor in
                            await store.convertAllTripsToGlobalCurrency()
                        }
                    }
                }
                
                Section(header: Text("Data Recovery"), footer: Text("If your trip data is missing, tap this button to attempt recovery from backups.")) {
                    Button("🚨 Attempt Data Recovery") {
                        let success = store.attemptDataRecovery()
                        if success {
                            recoveryMessage = "✅ Data recovery successful! Your trips have been restored."
                        } else {
                            recoveryMessage = "❌ No recoverable data found. Please contact support if this issue persists."
                        }
                        showingRecoveryAlert = true
                    }
                    .foregroundColor(.primaryPink)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Data Recovery", isPresented: $showingRecoveryAlert) {
                Button("OK") { }
            } message: {
                Text(recoveryMessage)
            }
        }
    }
}

struct CategoryCard: View {
    let category: ExpenseCategory
    @EnvironmentObject var store: TripStore
    @Binding var trip: Trip
    @AppStorage("darkMode") private var darkMode = false
    var onEdit: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading) {
                    Text(category.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(darkMode ? .darkText : .black)
                    Text("Planned: \(formatCurrency(category.plannedAmount, currency: trip.currency))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(darkMode ? .darkSecondaryText : .gray)
                }
                Spacer()
                Button("Edit", action: onEdit)
                    .buttonStyle(BorderlessButtonStyle())
                Button(role: .destructive) {
                    trip.expectedCategories.removeAll { $0.id == category.id }
                    store.updateTrip(trip)
                } label: {
                    Image(systemName: "trash")
                }
            }
            ProgressView(value: actualForCategory(category), total: category.plannedAmount > 0 ? category.plannedAmount : 1)
                .accentColor(actualForCategory(category) <= category.plannedAmount ? .green : .red)
                .frame(height: 6)
                .clipShape(Capsule())
                .background(Capsule().fill(Color.gray.opacity(0.2)))
            HStack {
                Text("\(formatCurrency(actualForCategory(category), currency: trip.currency)) spent of \(formatCurrency(category.plannedAmount, currency: trip.currency))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(darkMode ? .darkSecondaryText : .gray)
                Spacer()
                Text("\(formatCurrency(category.plannedAmount - actualForCategory(category), currency: trip.currency)) left")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primaryPink)
            }
        }
        .padding(16)
        .background(darkMode ? Color.darkCard : Color.white)
        .cornerRadius(12)
        .shadow(color: darkMode ? Color.clear : Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                trip.expectedCategories.removeAll { $0.id == category.id }
                store.updateTrip(trip)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    private func actualForCategory(_ category: ExpenseCategory) -> Double {
        trip.actualExpenses.filter { $0.categoryId == category.id }.reduce(0) { $0 + $1.amount }
    }
}

struct ExpenseCard: View {
    let expense: Expense
    @EnvironmentObject var store: TripStore
    @Binding var trip: Trip
    @AppStorage("darkMode") private var darkMode = false
    var onEdit: () -> Void
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(expense.description)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(darkMode ? .darkText : .black)
                if let cat = trip.expectedCategories.first(where: { $0.id == expense.categoryId }) {
                    Text(cat.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(darkMode ? .darkSecondaryText : .gray)
                }
                Text("\(formatCurrency(expense.amount, currency: trip.currency)) on \(expense.date, formatter: dateFormatter)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(darkMode ? .darkSecondaryText : .gray)
            }
            Spacer()
            Button("Edit", action: onEdit)
                .buttonStyle(BorderlessButtonStyle())
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primaryPink)
            Button(role: .destructive) {
                trip.actualExpenses.removeAll { $0.id == expense.id }
                store.updateTrip(trip)
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding(16)
        .background(darkMode ? Color.darkCard : Color.white)
        .cornerRadius(12)
        .shadow(color: darkMode ? Color.clear : Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}



private let dateFormatter: DateFormatter = {
    let df = DateFormatter()
    df.dateStyle = .short
    df.timeStyle = .none
    return df
}()

#Preview {
    let store = TripStore()
    if store.trips.isEmpty {
        // Create a sample trip with some data for preview
        let trip = Trip(id: UUID(), name: "Sample Trip", budget: 1000, icon: "✈️", 
                       expectedCategories: [ExpenseCategory(id: UUID(), name: "Food", plannedAmount: 300)], 
                       actualExpenses: [Expense(id: UUID(), categoryId: UUID(), amount: 50, description: "Lunch", date: Date())], 
                       startDate: nil, endDate: nil, lastUpdated: Date())
        store.trips.append(trip)
    }
    return ContentView().environmentObject(store)
}

