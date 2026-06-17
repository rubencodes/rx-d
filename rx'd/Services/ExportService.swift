import Foundation

enum ExportService {
    static func generateCSV(logs: [DoseLog], prescriptions: [Prescription]) -> String {
        let header = "prescription_name,prescription_id,scheduled_date,scheduled_time,status,completed_at,snooze_count,note\n"
        let rows = logs.map { log -> String in
            let name = prescriptions.first { $0.id == log.prescriptionId }?.name ?? ""
            return [
                name.csvEscaped,
                log.prescriptionId.uuidString,
                log.scheduledDate.isoDateString,
                log.scheduledDate.isoTimeString,
                log.status.rawValue,
                log.completedAt?.iso8601String ?? "",
                "\(log.snoozeCount)",
                log.noteText?.csvEscaped ?? "",
            ].joined(separator: ",")
        }.joined(separator: "\n")
        return header + rows
    }
}
