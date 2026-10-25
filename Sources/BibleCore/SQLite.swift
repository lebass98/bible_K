import Foundation
import SQLite3

/// macOS에 들어 있는 SQLite를 쓰는 아주 얇은 감싸개
public final class SQLiteDB {
    public struct Failure: Error, CustomStringConvertible {
        public let description: String
    }

    private var handle: OpaquePointer?
    public let path: String

    public init(path: String, readOnly: Bool = false) throws {
        self.path = path
        let flags = readOnly ? SQLITE_OPEN_READONLY : (SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
        if sqlite3_open_v2(path, &handle, flags | SQLITE_OPEN_FULLMUTEX, nil) != SQLITE_OK {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "열 수 없음"
            sqlite3_close(handle)
            handle = nil
            throw Failure(description: "DB 열기 실패(\(path)): \(message)")
        }
    }

    deinit { sqlite3_close(handle) }

    public func exec(_ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(handle, sql, nil, nil, &error) != SQLITE_OK {
            let message = error.map { String(cString: $0) } ?? "알 수 없는 오류"
            sqlite3_free(error)
            throw Failure(description: "\(message) — \(sql.prefix(80))")
        }
    }

    public func prepare(_ sql: String) throws -> Statement {
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) != SQLITE_OK {
            throw Failure(description: "\(String(cString: sqlite3_errmsg(handle))) — \(sql.prefix(80))")
        }
        return Statement(stmt!)
    }

    /// 한 번 실행하고 모든 행을 돌려줌
    public func query<T>(_ sql: String, _ args: [Any?] = [], row: (Statement) -> T) -> [T] {
        guard let stmt = try? prepare(sql) else { return [] }
        stmt.bind(args)
        var result: [T] = []
        while stmt.step() { result.append(row(stmt)) }
        return result
    }

    @discardableResult
    public func run(_ sql: String, _ args: [Any?] = []) -> Bool {
        guard let stmt = try? prepare(sql) else { return false }
        stmt.bind(args)
        return stmt.stepDone()
    }

    public func transaction(_ body: () throws -> Void) throws {
        try exec("BEGIN")
        do {
            try body()
            try exec("COMMIT")
        } catch {
            try? exec("ROLLBACK")
            throw error
        }
    }
}

public final class Statement {
    private let stmt: OpaquePointer
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(_ stmt: OpaquePointer) { self.stmt = stmt }
    deinit { sqlite3_finalize(stmt) }

    public func bind(_ args: [Any?]) {
        sqlite3_reset(stmt)
        sqlite3_clear_bindings(stmt)
        for (offset, value) in args.enumerated() {
            let index = Int32(offset + 1)
            switch value {
            case nil: sqlite3_bind_null(stmt, index)
            case let v as Int: sqlite3_bind_int64(stmt, index, Int64(v))
            case let v as Double: sqlite3_bind_double(stmt, index, v)
            case let v as String: sqlite3_bind_text(stmt, index, v, -1, Self.transient)
            case let v as Bool: sqlite3_bind_int64(stmt, index, v ? 1 : 0)
            default: sqlite3_bind_text(stmt, index, "\(value!)", -1, Self.transient)
            }
        }
    }

    /// 행이 있으면 true
    public func step() -> Bool { sqlite3_step(stmt) == SQLITE_ROW }

    /// INSERT 같은 문장 실행. 성공하면 true
    @discardableResult
    public func stepDone() -> Bool {
        let code = sqlite3_step(stmt)
        return code == SQLITE_DONE || code == SQLITE_ROW
    }

    public func int(_ column: Int32) -> Int { Int(sqlite3_column_int64(stmt, column)) }

    public func string(_ column: Int32) -> String? {
        guard let text = sqlite3_column_text(stmt, column) else { return nil }
        return String(cString: text)
    }

    public func text(_ column: Int32) -> String { string(column) ?? "" }
}
