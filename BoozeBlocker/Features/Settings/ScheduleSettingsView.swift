import SwiftUI

struct ScheduleSettingsView: View {
    @State private var schedules: [ProtectionSchedule] = []
    @State private var showAddSchedule = false
    
    var body: some View {
        List {
            // Info section
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Scheduled Protection")
                            .fontWeight(.semibold)
                        Text("Automatically activate protection at set times")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Schedules list
            if schedules.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No schedules set")
                            .font(.headline)
                        Text("Add a schedule to automatically protect yourself")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            } else {
                Section {
                    ForEach($schedules) { $schedule in
                        ScheduleRow(schedule: $schedule)
                    }
                    .onDelete(perform: deleteSchedules)
                } header: {
                    Text("Active Schedules")
                }
            }
            
            // Suggested schedules
            Section {
                SuggestedScheduleRow(
                    title: "Friday Night",
                    days: "Friday",
                    time: "8:00 PM - 8:00 AM"
                ) {
                    addSchedule(days: [.friday], startHour: 20, endHour: 8)
                }
                
                SuggestedScheduleRow(
                    title: "Weekend Nights",
                    days: "Fri, Sat",
                    time: "9:00 PM - 8:00 AM"
                ) {
                    addSchedule(days: [.friday, .saturday], startHour: 21, endHour: 8)
                }
            } header: {
                Text("Suggested")
            }
        }
        .navigationTitle("Schedules")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddSchedule = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSchedule) {
            AddScheduleSheet { schedule in
                schedules.append(schedule)
                saveSchedules()
            }
        }
        .onAppear {
            loadSchedules()
        }
    }
    
    private func loadSchedules() {
        if let data = UserDefaults.standard.data(forKey: "protectionSchedules"),
           let decoded = try? JSONDecoder().decode([ProtectionSchedule].self, from: data) {
            schedules = decoded
        }
    }
    
    private func saveSchedules() {
        if let encoded = try? JSONEncoder().encode(schedules) {
            UserDefaults.standard.set(encoded, forKey: "protectionSchedules")
        }
    }
    
    private func deleteSchedules(at offsets: IndexSet) {
        schedules.remove(atOffsets: offsets)
        saveSchedules()
    }
    
    private func addSchedule(days: Set<Weekday>, startHour: Int, endHour: Int) {
        let schedule = ProtectionSchedule(
            days: days,
            startHour: startHour,
            startMinute: 0,
            endHour: endHour,
            endMinute: 0,
            isEnabled: true
        )
        schedules.append(schedule)
        saveSchedules()
    }
}

struct ProtectionSchedule: Codable, Identifiable {
    let id: UUID
    var days: Set<Weekday>
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    var isEnabled: Bool
    
    init(
        id: UUID = UUID(),
        days: Set<Weekday>,
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.days = days
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.isEnabled = isEnabled
    }
    
    var daysDescription: String {
        let sortedDays = days.sorted { $0.rawValue < $1.rawValue }
        return sortedDays.map { $0.shortName }.joined(separator: ", ")
    }
    
    var timeDescription: String {
        let startTime = formatTime(hour: startHour, minute: startMinute)
        let endTime = formatTime(hour: endHour, minute: endMinute)
        return "\(startTime) - \(endTime)"
    }
    
    private func formatTime(hour: Int, minute: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        if minute == 0 {
            return "\(displayHour) \(period)"
        }
        return String(format: "%d:%02d %@", displayHour, minute, period)
    }
}

enum Weekday: Int, Codable, CaseIterable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
    
    var shortName: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }
    
    var fullName: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }
}

struct ScheduleRow: View {
    @Binding var schedule: ProtectionSchedule
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(schedule.daysDescription)
                    .fontWeight(.medium)
                Text(schedule.timeDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $schedule.isEnabled)
                .labelsHidden()
        }
    }
}

struct SuggestedScheduleRow: View {
    let title: String
    let days: String
    let time: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text("\(days) • \(time)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.blue)
            }
        }
    }
}

struct AddScheduleSheet: View {
    let onSave: (ProtectionSchedule) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDays: Set<Weekday> = []
    @State private var startTime = Date()
    @State private var endTime = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(Weekday.allCases, id: \.self) { day in
                            DayButton(
                                day: day,
                                isSelected: selectedDays.contains(day)
                            ) {
                                if selectedDays.contains(day) {
                                    selectedDays.remove(day)
                                } else {
                                    selectedDays.insert(day)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Days")
                }
                
                Section {
                    DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                } header: {
                    Text("Time")
                }
            }
            .navigationTitle("Add Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSchedule()
                    }
                    .disabled(selectedDays.isEmpty)
                }
            }
        }
    }
    
    private func saveSchedule() {
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)
        
        let schedule = ProtectionSchedule(
            days: selectedDays,
            startHour: startComponents.hour ?? 20,
            startMinute: startComponents.minute ?? 0,
            endHour: endComponents.hour ?? 8,
            endMinute: endComponents.minute ?? 0
        )
        
        onSave(schedule)
        dismiss()
    }
}

struct DayButton: View {
    let day: Weekday
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(day.shortName)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.1))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(8)
        }
    }
}

#Preview {
    NavigationStack {
        ScheduleSettingsView()
    }
}
