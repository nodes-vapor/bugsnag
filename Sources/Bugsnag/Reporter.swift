import Vapor
import HTTP

public protocol ReporterType {
    func report(error: Error, request: Request, userId: String?, userName: String?, userEmail: String?, lineNumber: Int?, funcName: String?, fileName: String?, version: String?) throws
    
    func report(error: Error, request: Request, lineNumber: Int?, funcName: String?, fileName: String?, version: String?) throws
    
    func report(
        error: Error,
        request: Request,
        severity: Severity,
        userId: String?,
        userName: String?,
        userEmail: String?,
        lineNumber: Int?,
        funcName: String?,
        fileName: String?,
        version: String?,
        completion: (() -> ())?
    ) throws
}

public enum Severity: String {
    case error, warning, info
}

public final class Bugsnag: ReporterType, Service {
    public func report(error: Error, request: Request, userId: String?, userName: String?, userEmail: String?, lineNumber: Int?, funcName: String?, fileName: String?, version: String?) throws {
        report(error: error, request: request, severity: .error, userId: userId, userName: userName, userEmail: userEmail, lineNumber: lineNumber, funcName: funcName, fileName: fileName, version: version, completion: nil)
    }
    
    
    let environment: Environment
    let notifyReleaseStages: [Environment]?
    let connectionManager: ConnectionManager
    let payloadTransformer: PayloadTransformerType
    
    init(
        environment: Environment,
        notifyReleaseStages: [Environment]? = [],
        connectionManager: ConnectionManager,
        transformer: PayloadTransformerType
    ) {
        self.environment = environment
        self.notifyReleaseStages = notifyReleaseStages
        self.connectionManager = connectionManager
        self.payloadTransformer = transformer
    }

    public func report(error: Error, request: Request, lineNumber: Int?, funcName: String?, fileName: String?, version: String?) {
        report(error: error, request: request, severity: .error, userId: nil, userName: nil, userEmail: nil, lineNumber: lineNumber, funcName: funcName, fileName: fileName, version: version, completion: nil)
    }
    
    public func report(
        error: Error,
        request: Request,
        severity: Severity = .error,
        userId: String?,
        userName: String?,
        userEmail: String?,
        lineNumber: Int?,
        funcName: String?,
        fileName: String?,
        version: String?,
        completion complete: (() -> ())?
        ) {
        guard let error = error as? AbortError else {
            report(
                message: "Internal Server Error",
                request: request,
                severity: severity,
                lineNumber: lineNumber,
                funcName: funcName,
                fileName: fileName,
                userId: userId,
                userName: userName,
                userEmail: userEmail,
                version: version,
                completion: complete
            )
            
            return
        }

        guard shouldNotifyForReleaseStage() else {
            return
        }

        report(
            message: error.reason,
            request: request,
            severity: severity,
            lineNumber: lineNumber,
            funcName: funcName,
            fileName: fileName,
            userId: userId,
            userName: userName,
            userEmail: userEmail,
            version: version,
            completion: complete
        )
    }
    
    // MARK: - Private helpers

    private func report(
        message: String,
        request: Request,
        severity: Severity,
        lineNumber: Int? = nil,
        funcName: String? = nil,
        fileName: String? = nil,
        userId: String?,
        userName: String?,
        userEmail: String?,
        version: String?,
        completion complete: (() -> ())? = nil
        ) {
        let payload = try? payloadTransformer.payloadFor(
            message: message,
            request: request,
            severity: severity,
            lineNumber: lineNumber,
            funcName: funcName,
            fileName: fileName,
            userId: userId,
            userName: userName,
            userEmail: userEmail,
            version: version
        )

        if let payload = payload {
            _ = try? self.connectionManager.submitPayload(payload).map(to: Void.self) { _ in
                if let complete = complete { complete() }
                return ()
            }
        }
    }

    private func shouldNotifyForReleaseStage() -> Bool {
        // If a user doesn't explicitly set this, report on all stages
        guard let notifyReleaseStages = notifyReleaseStages else {
            return true
        }
        
        return notifyReleaseStages.contains(environment)
    }
}
