//
//  ContentView.swift
//  Vacation Budget App
//
//  Created by Loren Harrison Franck on 6/19/25.
//

import SwiftUI

// MARK: - Currency Formatting Helper
func formatCurrency(_ amount: Double) -> String {
    if amount.truncatingRemainder(dividingBy: 1) == 0 {
        return String(format: "%.0f", amount)
    } else {
        return String(format: "%.2f", amount)
    }
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
    var icon: String // Added icon field
    var expectedCategories: [ExpenseCategory]
    var actualExpenses: [Expense]
    var startDate: Date?
    var endDate: Date?
    var lastUpdated: Date
    var isDeleted: Bool = false
    var deletedAt: Date? = nil
}

class TripStore: ObservableObject {
    @Published var trips: [Trip] = [] {
        didSet { save() }
    }
    @Published var yearlyBudget: Double = 0 {
        didSet { saveYearlyBudget() }
    }
    
    let tripsKey = "trips_key"
    let yearlyBudgetKey = "yearly_budget_key"
    
    var activeTrips: [Trip] { trips.filter { !$0.isDeleted && !isPastTrip($0) } }
    var pastTrips: [Trip] { trips.filter { !$0.isDeleted && isPastTrip($0) } }
    var recentlyDeleted: [Trip] { trips.filter { $0.isDeleted } }
    
    var totalSpentThisYear: Double {
        trips.filter { !$0.isDeleted }.reduce(0) { total, trip in
            total + trip.actualExpenses.reduce(0) { $0 + $1.amount }
        }
    }
    
    private func isPastTrip(_ trip: Trip) -> Bool {
        guard let endDate = trip.endDate else { return false }
        return Calendar.current.isDate(endDate, inSameDayAs: Date()) || endDate < Date()
    }
    
    init() {
        load()
        loadYearlyBudget()
    }
    
    func addTrip(name: String, budget: Double, icon: String, startDate: Date?, endDate: Date?) {
        let trip = Trip(id: UUID(), name: name, budget: budget, icon: icon, expectedCategories: [], actualExpenses: [], startDate: startDate, endDate: endDate, lastUpdated: Date())
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
            var trip = activeTrips[idx]
            trip.isDeleted = true
            trip.deletedAt = Date()
            updateTrip(trip)
        }
    }
    
    func restoreTrip(_ trip: Trip) {
        if let idx = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[idx].isDeleted = false
            trips[idx].deletedAt = nil
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
    
    func cleanRecentlyDeleted() {
        let now = Date()
        trips.removeAll { $0.isDeleted && $0.deletedAt != nil && now.timeIntervalSince($0.deletedAt!) > 30*24*60*60 }
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(trips) {
            UserDefaults.standard.set(data, forKey: tripsKey)
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: tripsKey),
           let saved = try? JSONDecoder().decode([Trip].self, from: data) {
            trips = saved
        }
    }
    
    private func saveYearlyBudget() {
        UserDefaults.standard.set(yearlyBudget, forKey: yearlyBudgetKey)
    }
    
    private func loadYearlyBudget() {
        yearlyBudget = UserDefaults.standard.double(forKey: yearlyBudgetKey)
    }
}

struct ContentView: View {
    @StateObject private var store = TripStore()
    @State private var showingAddTrip = false
    @AppStorage("darkMode") private var darkMode = false
    @State private var selectedTripId: UUID? = nil
    @State private var sortOption: SortOption = .manual
    @State private var showingSettings = false
    @State private var showingYearlyBudgetEdit = false
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var showDatePickers = false
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
    
    var body: some View {
        NavigationView {
            ZStack {
                (darkMode ? Color.darkBackground : Color.white)
                    .ignoresSafeArea()
                if sortedActiveTrips.isEmpty && sortedPastTrips.isEmpty {
                    VStack {
                        Spacer()
                        Button(action: { showingAddTrip = true }) {
                            HStack {
                                Image(systemName: "plus")
                                Text("Add Trip")
                                    .font(.system(size: 28, weight: .bold, design: .default))
                            }
                            .padding(.horizontal, 32)
                            .padding(.vertical, 20)
                            .background(Capsule().fill(LinearGradient(gradient: Gradient(colors: [Color.primaryPink, Color.secondaryPink]), startPoint: .leading, endPoint: .trailing)))
                            .foregroundColor(.white)
                            .shadow(color: Color.primaryPink.opacity(0.4), radius: 12, x: 0, y: 6)
                        }
                        .accessibilityLabel("Add Trip")
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(
                        HStack {
                            Button(action: { showingSettings = true }) {
                                Image(systemName: "gearshape.fill")
                                    .resizable()
                                    .frame(width: 32, height: 32)
                                    .foregroundColor(.primaryPink)
                                    .padding(16)
                                    .background(Circle().fill(Color.lightPink.opacity(0.3)))
                                    .shadow(color: .primaryPink.opacity(0.2), radius: 4, x: 0, y: 2)
                            }
                            Spacer()
                        }
                        .padding(.bottom, 32)
                        .padding(.leading, 24)
                        , alignment: .bottomLeading
                    )
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
                                Section("Active Trips") {
                                    ForEach(sortedActiveTrips) { trip in
                                NavigationLink(destination: TripDetailView(trip: trip).environmentObject(store), tag: trip.id, selection: $selectedTripId) {
                                    TripCardView(trip: trip)
                                }
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
                                Section("Past Trips") {
                                    ForEach(sortedPastTrips) { trip in
                                        NavigationLink(destination: TripDetailView(trip: trip).environmentObject(store), tag: trip.id, selection: $selectedTripId) {
                                            TripCardView(trip: trip)
                                        }
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
                TripFormView { name, budget, icon, startDate, endDate in
                    store.addTrip(name: name, budget: budget, icon: icon, startDate: startDate, endDate: endDate)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Yearly Vacation Budget")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(darkMode ? .darkText : .black)
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
                    Text("$\(formatCurrency(store.totalSpentThisYear)) spent of $\(formatCurrency(store.yearlyBudget))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(darkMode ? .darkSecondaryText : .gray)
                    Spacer()
                    Text("$\(formatCurrency(store.yearlyBudget - store.totalSpentThisYear)) left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primaryPink)
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
        .shadow(color: .gray.opacity(0.15), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(darkMode ? Color.darkCard.opacity(0.3) : Color.gray.opacity(0.08), lineWidth: 1)
        )
    }
}

struct YearlyBudgetEditView: View {
    @ObservedObject var store: TripStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("darkMode") private var darkMode = false
    @State private var budget: String = ""
    
    var displayAmount: String {
        if budget.isEmpty {
            return "$0"
        }
        if let value = Double(budget) {
            if value.truncatingRemainder(dividingBy: 1) == 0 {
                return "$\(String(format: "%.0f", value))"
            } else {
                return "$\(String(format: "%.2f", value))"
            }
        }
        return "$\(budget)"
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
                
                Spacer()
                
                // Number pad with better spacing
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
                .padding(.bottom, 16)
                
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
                budget = formatCurrency(store.yearlyBudget)
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
    @State private var showingEditTrip = false
    
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
                Text("Budget: $\(formatCurrency(trip.budget))")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(darkMode ? .darkSecondaryText : .gray)
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
                        Text("$\(formatCurrency(totalActual)) spent of $\(formatCurrency(totalPlanned)) planned")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(darkMode ? .darkSecondaryText : .gray)
                        Spacer()
                        Text("$\(formatCurrency(totalPlanned - totalActual)) left")
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
                        Text("Total: $\(formatCurrency(plannedSoFar))")
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
            CategoryFormView(tripBudget: trip.budget, currentPlannedTotal: plannedSoFar) { name, amount in
                if canAddCategory(amount: amount) {
                    let newCat = ExpenseCategory(id: UUID(), name: name, plannedAmount: amount)
                    trip.expectedCategories.append(newCat)
                    store.updateTrip(trip)
                    showingAddCategory = false
                } else {
                    budgetAlertMessage = "Adding this category would exceed the trip's budget."
                    showBudgetAlert = true
                }
            }
        }
        .sheet(item: $editingCategory) { category in
            CategoryFormView(category: category, tripBudget: trip.budget, currentPlannedTotal: plannedSoFar - category.plannedAmount) { name, amount in
                if canAddCategory(amount: amount, editing: category) {
                    if let idx = trip.expectedCategories.firstIndex(where: { $0.id == category.id }) {
                        trip.expectedCategories[idx].name = name
                        trip.expectedCategories[idx].plannedAmount = amount
                        store.updateTrip(trip)
                    }
                    editingCategory = nil
                } else {
                    budgetAlertMessage = "Editing this category would exceed the trip's budget."
                    showBudgetAlert = true
                }
            }
        }
        .sheet(isPresented: $showingAddExpense) {
            ExpenseFormView(categories: trip.expectedCategories, categorySpending: categorySpendingMap) { catId, amount, desc in
                let newExp = Expense(id: UUID(), categoryId: catId, amount: amount, description: desc, date: Date())
                trip.actualExpenses.append(newExp)
                store.updateTrip(trip)
                showingAddExpense = false
            }
        }
        .sheet(item: $editingExpense) { expense in
            ExpenseFormView(expense: expense, categories: trip.expectedCategories, categorySpending: adjustedCategorySpending(excluding: expense)) { catId, amount, desc in
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
        .sheet(isPresented: $showingEditTrip) {
            TripFormView(trip: trip) { name, budget, icon, startDate, endDate in
                trip.name = name
                trip.budget = budget
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
        .shadow(color: .gray.opacity(0.15), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(darkMode ? Color.darkCard.opacity(0.3) : Color.gray.opacity(0.08), lineWidth: 1)
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
                Text("$\(formatCurrency(spent))")
                    .font(.system(size: 20, weight: .bold, design: .default))
                    .foregroundColor(darkMode ? .darkText : .black)
                Text("spent")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(darkMode ? .darkSecondaryText : .gray)
                Spacer()
            }
            HStack {
                Text("$\(formatCurrency(left))")
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
    var onSave: (String, Double, String, Date?, Date?) -> Void
    @Environment(\.dismiss) private var dismiss
    @AppStorage("darkMode") private var darkMode = false
    @State private var name: String = ""
    @State private var budget: String = ""
    @State private var selectedIcon: String = "✈️"
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var showDatePicker = false
    @State private var showingIconPicker = false
    @State private var dateSelectionStep: DateSelectionStep = .start
    @State private var hasSelectedDates = false
    
    enum DateSelectionStep {
        case start, end, complete
    }
    
    private let availableIcons = ["✈️", "🚗", "🏖️", "🏔️", "🌴", "🚢", "🏕️", "🏝️", "🌊", "🏜️", "🏞️", "⛰️", "🌋", "🗻", "🏰", "🏛️", "🍻", "⛳", "🐬", "🎿", "🏄", "🚁", "🎢", "🎡"]
    
    var displayAmount: String {
        if budget.isEmpty {
            return "$0"
        }
        if let value = Double(budget) {
            // Show decimals only if there's a fractional part
            if value.truncatingRemainder(dividingBy: 1) == 0 {
                return "$\(String(format: "%.0f", value))"
            } else {
                return "$\(String(format: "%.2f", value))"
            }
        }
        return "$\(budget)"
    }
    
    var dateRangeDisplay: String {
        if hasSelectedDates {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        }
        return ""
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
                .padding(.top, 40)
                
                // Large amount display with balanced spacing
                Text(displayAmount)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(darkMode ? .darkText : .black)
                    .padding(.vertical, 16)
                
                // Form fields with consistent spacing
                VStack(spacing: 16) {
                    // Trip Icon picker
                    Button(action: { showingIconPicker = true }) {
                        HStack {
                            Text(selectedIcon)
                                .font(.system(size: 24))
                                .frame(width: 20, height: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Trip Icon")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(darkMode ? .darkSecondaryText : .gray)
                                Text("Tap to change")
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
                    
                    // Trip name field
                    HStack {
                        Image(systemName: "textformat")
                            .foregroundColor(.primaryPink)
                            .frame(width: 20, height: 20)
                        
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
                    
                    // Dates section - Fixed toggle behavior
                    VStack(spacing: 0) {
                        HStack {
                            Text("Add Dates")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(darkMode ? .darkText : .black)
                            Spacer()
                            if !dateRangeDisplay.isEmpty {
                                Text(dateRangeDisplay)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.primaryPink)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.lightPink.opacity(0.2))
                                    .cornerRadius(6)
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
                                        }
                                    } else {
                                        // When turned OFF, clear dates and hide calendar
                                        showDatePicker = false
                                        startDate = Date()
                                        endDate = Date()
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
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.primaryPink)
                                    Spacer()
                                    Button("Done") {
                                        showDatePicker = false
                                        // Keep toggle ON when dates are selected
                                        if dateSelectionStep == .complete {
                                            hasSelectedDates = true
                                        }
                                    }
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.primaryPink)
                                }
                                
                                DatePicker("", selection: dateSelectionStep == .start ? $startDate : $endDate, displayedComponents: .date)
                                    .datePickerStyle(GraphicalDatePickerStyle())
                                    .accentColor(.primaryPink)
                                    .onChange(of: startDate) { _ in
                                        if dateSelectionStep == .start {
                                            dateSelectionStep = .end
                                            if endDate < startDate {
                                                endDate = startDate
                                            }
                                        }
                                    }
                                    .onChange(of: endDate) { _ in
                                        if dateSelectionStep == .end {
                                            dateSelectionStep = .complete
                                            hasSelectedDates = true
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
                
                // Number pad with better spacing
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
                .padding(.bottom, 16)
                
                // Continue button with proper spacing
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
                        onSave(name, budgetValue, selectedIcon, hasSelectedDates ? startDate : nil, hasSelectedDates ? endDate : nil)
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
                .disabled(name.isEmpty || Double(budget) == nil)
                .opacity((name.isEmpty || Double(budget) == nil) ? 0.6 : 1.0)
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $showingIconPicker) {
            IconPickerView(selectedIcon: $selectedIcon)
        }
        .onAppear {
            if let trip = trip {
                name = trip.name
                budget = formatCurrency(trip.budget)
                selectedIcon = trip.icon
                startDate = trip.startDate ?? Date()
                endDate = trip.endDate ?? Date()
                hasSelectedDates = trip.startDate != nil
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
    var tripBudget: Double = 0
    var currentPlannedTotal: Double = 0
    var onSave: (String, Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @AppStorage("darkMode") private var darkMode = false
    @State private var name: String = ""
    @State private var amount: String = ""
    
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
            return "⚠️ This would exceed your remaining budget of $\(String(format: "%.0f", remaining))"
        }
    }
    
    var displayAmount: String {
        if amount.isEmpty {
            return "$0"
        }
        if let value = Double(amount) {
            // Show decimals only if there's a fractional part
            if value.truncatingRemainder(dividingBy: 1) == 0 {
                return "$\(String(format: "%.0f", value))"
            } else {
                return "$\(String(format: "%.2f", value))"
            }
        }
        return "$\(amount)"
    }
    
    var body: some View {
        ZStack {
            (darkMode ? Color.darkBackground : Color.white).ignoresSafeArea()
            
            VStack(spacing: 16) {
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
                .padding(.top, 40)
                
                // Large amount display
                Text(displayAmount)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(darkMode ? .darkText : .black)
                    .padding(.vertical, 12)
                
                // Form fields
                VStack(spacing: 12) {
                    // Category name field
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.primaryPink)
                            .frame(width: 20, height: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Category Name")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(darkMode ? .darkSecondaryText : .gray)
                            TextField("Enter category name", text: $name)
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
                
                // Number pad - always visible
                VStack(spacing: 12) {
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
                .padding(.bottom, 12)
                
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
                .disabled(name.isEmpty || Double(amount) == nil)
                .opacity((name.isEmpty || Double(amount) == nil) ? 0.6 : 1.0)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            if let category = category {
                name = category.name
                amount = formatCurrency(category.plannedAmount)
            }
        }
    }
}

struct ExpenseFormView: View {
    var expense: Expense? = nil
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
            return "💚 Great! You'll have $\(formatCurrency(remaining)) left in \(category.name)"
        } else if newTotal <= category.plannedAmount * 0.8 {
            return "👍 On track - $\(formatCurrency(remaining)) remaining for \(category.name)"
        } else if newTotal <= category.plannedAmount {
            return "⚡ Getting close - $\(formatCurrency(remaining)) left for \(category.name)"
        } else {
            return "⚠️ This would put you $\(formatCurrency(abs(remaining))) over budget for \(category.name)"
        }
    }
    
    var displayAmount: String {
        if amount.isEmpty {
            return "$0"
        }
        if let value = Double(amount) {
            // Show decimals only if there's a fractional part
            if value.truncatingRemainder(dividingBy: 1) == 0 {
                return "$\(String(format: "%.0f", value))"
            } else {
                return "$\(String(format: "%.2f", value))"
            }
        }
        return "$\(amount)"
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
            
            VStack(spacing: 16) {
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
                .padding(.top, 40)
                
                // Large amount display
                Text(displayAmount)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(darkMode ? .darkText : .black)
                    .padding(.vertical, 12)
                
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
                
                // Number pad - always visible
                VStack(spacing: 12) {
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
                .padding(.bottom, 12)
                
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
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            if let expense = expense {
                selectedCategory = expense.categoryId
                amount = formatCurrency(expense.amount)
                desc = expense.description
            }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var store: TripStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("darkMode") private var darkMode = false
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Appearance")) {
                    Toggle("Dark Mode", isOn: $darkMode)
                }
                Section(header: Text("Recently Deleted")) {
                    if store.recentlyDeleted.isEmpty {
                        Text("No recently deleted trips.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(store.recentlyDeleted) { trip in
                            HStack {
                                Text(trip.name)
                                Spacer()
                                Button("Restore") { store.restoreTrip(trip) }
                                    .foregroundColor(.blue)
                                Button("Delete") { store.permanentlyDeleteTrip(trip) }
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
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
                    Text("Planned: $\(formatCurrency(category.plannedAmount))")
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
                Text("$\(formatCurrency(actualForCategory(category))) spent of $\(formatCurrency(category.plannedAmount))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(darkMode ? .darkSecondaryText : .gray)
                Spacer()
                Text("$\(formatCurrency(category.plannedAmount - actualForCategory(category))) left")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primaryPink)
            }
        }
        .padding(16)
        .background(darkMode ? Color.darkCard : Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
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
                Text("$\(formatCurrency(expense.amount)) on \(expense.date, formatter: dateFormatter)")
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
        .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
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
