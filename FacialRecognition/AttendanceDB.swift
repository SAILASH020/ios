import Foundation
import SQLite3

class AttendanceDB {
    static let shared = AttendanceDB()
    private var db: OpaquePointer?
    
    private init() { setupDatabase() }
    
    private func setupDatabase() {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("Attendance_v4.sqlite")
        
        if sqlite3_open(fileURL.path, &db) != SQLITE_OK { return }
        
        sqlite3_exec(db, "CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, embedding BLOB);", nil, nil, nil)
        sqlite3_exec(db, "CREATE TABLE IF NOT EXISTS logs (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, date TEXT, clock_in TEXT, clock_out TEXT);", nil, nil, nil)
    }

    func findMatch(newVector: [Float], threshold: Float = 0.7) -> String? {
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT name, embedding FROM users;", -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let name = String(cString: sqlite3_column_text(stmt, 0))
                let blob = sqlite3_column_blob(stmt, 1)
                let len = Int(sqlite3_column_bytes(stmt, 1))
                let data = Data(bytes: blob!, count: len)
                let savedVector = data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
                
                let dist = sqrt(zip(newVector, savedVector).map { pow($0 - $1, 2) }.reduce(0, +))
                if dist < threshold { sqlite3_finalize(stmt); return name }
            }
        }
        sqlite3_finalize(stmt); return nil
    }

    func registerUser(name: String, vector: [Float]) {
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "INSERT INTO users (name, embedding) VALUES (?, ?);", -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (name as NSString).utf8String, -1, nil)
            let data = Data(buffer: UnsafeBufferPointer(start: vector, count: vector.count))
            sqlite3_bind_blob(stmt, 2, (data as NSData).bytes, Int32(data.count), nil)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    func logAttendance(name: String) -> String {
        let fullTime = getCurrentTimestamp()
        let dateOnly = String(fullTime.prefix(10))
        var rowID: Int32 = -1
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, "SELECT id FROM logs WHERE name = ? AND date = ? AND clock_out IS NULL LIMIT 1;", -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (name as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (dateOnly as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW { rowID = sqlite3_column_int(stmt, 0) }
        }
        sqlite3_finalize(stmt)
        
        let sql = rowID != -1 ? "UPDATE logs SET clock_out = ? WHERE id = ?;" : "INSERT INTO logs (name, date, clock_in) VALUES (?, ?, ?);"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            if rowID != -1 {
                sqlite3_bind_text(stmt, 1, (fullTime as NSString).utf8String, -1, nil)
                sqlite3_bind_int(stmt, 2, rowID)
            } else {
                sqlite3_bind_text(stmt, 1, (name as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (dateOnly as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 3, (fullTime as NSString).utf8String, -1, nil)
            }
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
        return rowID != -1 ? "Clocked Out 🚪" : "Clocked In ✅"
    }

    func getAllUserNames() -> [String] {
        var stmt: OpaquePointer?; var names: [String] = []
        if sqlite3_prepare_v2(db, "SELECT name FROM users ORDER BY name ASC;", -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW { names.append(String(cString: sqlite3_column_text(stmt, 0))) }
        }
        sqlite3_finalize(stmt); return names
    }

    func deleteUser(name: String) {
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "DELETE FROM users WHERE name = ?;", -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (name as NSString).utf8String, -1, nil)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    func getTodayLogs() -> [[String: String]] {
        let today = String(getCurrentTimestamp().prefix(10))
        var stmt: OpaquePointer?; var results: [[String: String]] = []
        if sqlite3_prepare_v2(db, "SELECT name, clock_in, clock_out FROM logs WHERE date = ? ORDER BY clock_in DESC;", -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (today as NSString).utf8String, -1, nil)
            while sqlite3_step(stmt) == SQLITE_ROW {
                results.append([
                    "name": String(cString: sqlite3_column_text(stmt, 0)),
                    "in": String(cString: sqlite3_column_text(stmt, 1)),
                    "out": sqlite3_column_text(stmt, 2) != nil ? String(cString: sqlite3_column_text(stmt, 2)) : "--:--"
                ])
            }
        }
        sqlite3_finalize(stmt); return results
    }

    private func getCurrentTimestamp() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm:ss"; return f.string(from: Date())
    }
}
