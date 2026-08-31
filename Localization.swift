import Foundation

enum CopyKey: String {
    case appName
    case overview
    case settings
    case liveSignals
    case chooseStatusMetric
    case menuBarDisplay
    case language
    case refreshInterval
    case refreshRates
    case codexRefreshRate
    case lightsailRefreshRate
    case yuhaiinRefreshRate
    case cycleDisplayRate
    case refreshHint
    case seconds
    case save
    case cancel
    case refresh
    case updated
    case ready
    case waiting
    case unavailable
    case error
    case configure
    case close
    case codex
    case lightsail
    case yuhaiin
    case cycle
    case codexDescription
    case lightsailDescription
    case yuhaiinDescription
    case cycleDescription
    case remaining
    case used
    case total
    case download
    case upload
    case plan
    case credits
    case resetCredits
    case reset
    case window
    case resetIn
    case status
    case yuhaiinURL
    case yuhaiinToken
    case yuhaiinHint
    case awsSettings
    case awsAccessKey
    case awsSecretKey
    case awsSessionToken
    case awsRegion
    case awsProfile
    case awsHTTPHint
    case credentialsOptional
    case connectionFailed
    case noData
    case saveAndRefresh
    case closeSettings
    case live
    case instances
    case observed
    case details
    case closeDetails
    case tapForDetails
    case summary
    case account
    case rateLimit
    case primaryWindow
    case secondaryWindow
    case accountID
    case email
    case userID
    case available
    case applicable
    case local
    case cloud
    case allowance
    case networkIn
    case networkOut
    case publicIP
    case bundle
    case specification
    case system
    case endpoint
    case state
    case period
    case limited
    case ok
    case monthly
}

enum L10n {
    private static let table: [CopyKey: [AppLanguage: String]] = [
        .appName: [.traditionalChinese: "Status Bar", .english: "Status Bar", .japanese: "Status Bar", .korean: "Status Bar"],
        .overview: [.traditionalChinese: "總覽", .english: "Overview", .japanese: "概要", .korean: "개요"],
        .settings: [.traditionalChinese: "設定", .english: "Settings", .japanese: "設定", .korean: "설정"],
        .liveSignals: [.traditionalChinese: "即時訊號", .english: "Live signals", .japanese: "ライブシグナル", .korean: "실시간 신호"],
        .chooseStatusMetric: [.traditionalChinese: "選擇狀態列顯示", .english: "Choose status item", .japanese: "ステータス項目", .korean: "상태 표시 항목"],
        .menuBarDisplay: [.traditionalChinese: "狀態列顯示", .english: "Menu bar display", .japanese: "メニューバー表示", .korean: "메뉴 막대 표시"],
        .language: [.traditionalChinese: "語言", .english: "Language", .japanese: "言語", .korean: "언어"],
        .refreshInterval: [.traditionalChinese: "更新頻率", .english: "Refresh interval", .japanese: "更新間隔", .korean: "새로 고침 간격"],
        .refreshRates: [.traditionalChinese: "資料更新頻率", .english: "Data refresh rates", .japanese: "データ更新間隔", .korean: "데이터 새로 고침 간격"],
        .codexRefreshRate: [.traditionalChinese: "Codex 額度", .english: "Codex quota", .japanese: "Codex 使用量", .korean: "Codex 할당량"],
        .lightsailRefreshRate: [.traditionalChinese: "Lightsail 流量", .english: "Lightsail traffic", .japanese: "Lightsail 通信量", .korean: "Lightsail 트래픽"],
        .yuhaiinRefreshRate: [.traditionalChinese: "Yuhaiin 即時流量", .english: "Yuhaiin live traffic", .japanese: "Yuhaiin ライブ通信", .korean: "Yuhaiin 실시간 트래픽"],
        .cycleDisplayRate: [.traditionalChinese: "循環展示間隔", .english: "Rotation interval", .japanese: "ローテーション間隔", .korean: "순환 표시 간격"],
        .refreshHint: [.traditionalChinese: "Yuhaiin 可設定較短間隔；外部服務建議保留較長間隔以減少請求。", .english: "Yuhaiin can use a shorter interval; keep external services slower to reduce requests.", .japanese: "Yuhaiinは短い間隔に設定できます。外部サービスはリクエスト削減のため長めを推奨します。", .korean: "Yuhaiin은 짧은 간격을 사용할 수 있으며, 외부 서비스는 요청을 줄이도록 길게 설정하는 것을 권장합니다."],
        .seconds: [.traditionalChinese: "秒", .english: "sec", .japanese: "秒", .korean: "초"],
        .save: [.traditionalChinese: "儲存", .english: "Save", .japanese: "保存", .korean: "저장"],
        .cancel: [.traditionalChinese: "取消", .english: "Cancel", .japanese: "キャンセル", .korean: "취소"],
        .refresh: [.traditionalChinese: "重新整理", .english: "Refresh", .japanese: "更新", .korean: "새로 고침"],
        .updated: [.traditionalChinese: "更新於", .english: "Updated", .japanese: "更新", .korean: "업데이트"],
        .ready: [.traditionalChinese: "已連線", .english: "Ready", .japanese: "接続済み", .korean: "연결됨"],
        .waiting: [.traditionalChinese: "等待資料", .english: "Waiting", .japanese: "待機中", .korean: "대기 중"],
        .unavailable: [.traditionalChinese: "尚未設定", .english: "Not configured", .japanese: "未設定", .korean: "설정되지 않음"],
        .error: [.traditionalChinese: "讀取失敗", .english: "Read failed", .japanese: "読み込み失敗", .korean: "읽기 실패"],
        .configure: [.traditionalChinese: "前往設定", .english: "Open settings", .japanese: "設定を開く", .korean: "설정 열기"],
        .close: [.traditionalChinese: "關閉", .english: "Close", .japanese: "閉じる", .korean: "닫기"],
        .codex: [.traditionalChinese: "Codex 額度", .english: "Codex quota", .japanese: "Codex 使用量", .korean: "Codex 할당량"],
        .lightsail: [.traditionalChinese: "Lightsail 流量", .english: "Lightsail traffic", .japanese: "Lightsail 通信量", .korean: "Lightsail 트래픽"],
        .yuhaiin: [.traditionalChinese: "Yuhaiin 即時流量", .english: "Yuhaiin live traffic", .japanese: "Yuhaiin ライブ通信", .korean: "Yuhaiin 실시간 트래픽"],
        .cycle: [.traditionalChinese: "循環展示", .english: "Rotate metrics", .japanese: "メトリクスを循環", .korean: "지표 순환 표시"],
        .codexDescription: [.traditionalChinese: "ChatGPT Codex 5 小時視窗剩餘額度", .english: "Codex five-hour window remaining", .japanese: "Codex 5時間ウィンドウの残量", .korean: "Codex 5시간 창 잔여량"],
        .lightsailDescription: [.traditionalChinese: "AWS Lightsail 本月剩餘傳輸額度", .english: "AWS Lightsail monthly transfer remaining", .japanese: "AWS Lightsail 月間転送残量", .korean: "AWS Lightsail 월간 전송 잔량"],
        .yuhaiinDescription: [.traditionalChinese: "從管理 API 取得目前上下載速度", .english: "Current upload and download speed from the API", .japanese: "管理APIから現在の送受信速度を取得", .korean: "관리 API에서 현재 업로드 및 다운로드 속도"],
        .cycleDescription: [.traditionalChinese: "只循環顯示目前可取得資料的 provider", .english: "Rotate only through providers with available data", .japanese: "データを取得できるプロバイダーだけを循環表示", .korean: "데이터를 사용할 수 있는 provider만 순환 표시"],
        .remaining: [.traditionalChinese: "剩餘", .english: "remaining", .japanese: "残り", .korean: "남음"],
        .used: [.traditionalChinese: "已使用", .english: "used", .japanese: "使用済み", .korean: "사용"],
        .total: [.traditionalChinese: "總計", .english: "total", .japanese: "合計", .korean: "합계"],
        .download: [.traditionalChinese: "下載", .english: "Download", .japanese: "ダウンロード", .korean: "다운로드"],
        .upload: [.traditionalChinese: "上傳", .english: "Upload", .japanese: "アップロード", .korean: "업로드"],
        .plan: [.traditionalChinese: "方案", .english: "Plan", .japanese: "プラン", .korean: "요금제"],
        .credits: [.traditionalChinese: "Credits", .english: "Credits", .japanese: "クレジット", .korean: "크레딧"],
        .resetCredits: [.traditionalChinese: "Reset Credits", .english: "Reset Credits", .japanese: "リセットクレジット", .korean: "재설정 크레딧"],
        .reset: [.traditionalChinese: "重置", .english: "Reset", .japanese: "リセット", .korean: "재설정"],
        .window: [.traditionalChinese: "額度視窗", .english: "Window", .japanese: "ウィンドウ", .korean: "창"],
        .resetIn: [.traditionalChinese: "距離重置", .english: "Reset in", .japanese: "リセットまで", .korean: "재설정까지"],
        .status: [.traditionalChinese: "狀態", .english: "Status", .japanese: "ステータス", .korean: "상태"],
        .yuhaiinURL: [.traditionalChinese: "Yuhaiin 位址", .english: "Yuhaiin URL", .japanese: "Yuhaiin URL", .korean: "Yuhaiin URL"],
        .yuhaiinToken: [.traditionalChinese: "Yuhaiin Token", .english: "Yuhaiin token", .japanese: "Yuhaiin トークン", .korean: "Yuhaiin 토큰"],
        .yuhaiinHint: [.traditionalChinese: "預設管理位址為 http://127.0.0.1:50051；若啟用驗證，填入前端使用的 Basic token。", .english: "Default management address is http://127.0.0.1:50051. Add the Basic token if authentication is enabled.", .japanese: "既定の管理アドレスは http://127.0.0.1:50051。認証を有効にしている場合はBasic tokenを入力してください。", .korean: "기본 관리 주소는 http://127.0.0.1:50051입니다. 인증을 사용하면 Basic token을 입력하세요."],
        .awsSettings: [.traditionalChinese: "AWS Lightsail", .english: "AWS Lightsail", .japanese: "AWS Lightsail", .korean: "AWS Lightsail"],
        .awsAccessKey: [.traditionalChinese: "Access Key ID", .english: "Access key ID", .japanese: "Access Key ID", .korean: "Access Key ID"],
        .awsSecretKey: [.traditionalChinese: "Secret Access Key", .english: "Secret access key", .japanese: "Secret Access Key", .korean: "Secret Access Key"],
        .awsSessionToken: [.traditionalChinese: "Session Token（選填）", .english: "Session token (optional)", .japanese: "Session token（任意）", .korean: "Session token (선택 사항)"],
        .awsRegion: [.traditionalChinese: "Region", .english: "Region", .japanese: "リージョン", .korean: "리전"],
        .awsProfile: [.traditionalChinese: "Profile（若未填金鑰）", .english: "Profile (when keys are blank)", .japanese: "Profile（キー未入力時）", .korean: "Profile (키가 비어 있을 때)"],
        .awsHTTPHint: [.traditionalChinese: "透過原生 HTTPS / SigV4 直接呼叫 AWS，不需要安裝 CLI；金鑰會放在 macOS Keychain。", .english: "Uses native HTTPS / SigV4 directly, no AWS CLI required. Secrets are stored in the macOS Keychain.", .japanese: "AWS CLI不要のHTTPS / SigV4直接接続。秘密情報はmacOS Keychainに保存されます。", .korean: "AWS CLI 없이 HTTPS / SigV4로 직접 연결합니다. 비밀 키는 macOS Keychain에 저장됩니다."],
        .credentialsOptional: [.traditionalChinese: "若留白，會嘗試讀取環境變數或 ~/.aws/credentials。", .english: "When blank, environment variables or ~/.aws/credentials are used.", .japanese: "空欄の場合は環境変数または ~/.aws/credentials を使用します。", .korean: "비워 두면 환경 변수 또는 ~/.aws/credentials를 사용합니다."],
        .connectionFailed: [.traditionalChinese: "連線失敗", .english: "Connection failed", .japanese: "接続失敗", .korean: "연결 실패"],
        .noData: [.traditionalChinese: "尚無資料", .english: "No data yet", .japanese: "データなし", .korean: "데이터 없음"],
        .saveAndRefresh: [.traditionalChinese: "儲存並重新整理", .english: "Save & refresh", .japanese: "保存して更新", .korean: "저장 후 새로 고침"],
        .closeSettings: [.traditionalChinese: "返回總覽", .english: "Back to overview", .japanese: "概要に戻る", .korean: "개요로 돌아가기"],
        .live: [.traditionalChinese: "即時", .english: "Live", .japanese: "ライブ", .korean: "실시간"],
        .instances: [.traditionalChinese: "個執行個體", .english: "instances", .japanese: "インスタンス", .korean: "인스턴스"],
        .observed: [.traditionalChinese: "觀測", .english: "Observed", .japanese: "観測", .korean: "관측"],
        .details: [.traditionalChinese: "詳細資料", .english: "Details", .japanese: "詳細", .korean: "세부 정보"],
        .closeDetails: [.traditionalChinese: "返回總覽", .english: "Back to overview", .japanese: "概要に戻る", .korean: "개요로 돌아가기"],
        .tapForDetails: [.traditionalChinese: "點擊查看詳細資料", .english: "Click to view details", .japanese: "クリックして詳細を表示", .korean: "클릭하여 세부 정보 보기"],
        .summary: [.traditionalChinese: "摘要", .english: "Summary", .japanese: "概要", .korean: "요약"],
        .account: [.traditionalChinese: "帳戶", .english: "Account", .japanese: "アカウント", .korean: "계정"],
        .rateLimit: [.traditionalChinese: "額度限制", .english: "Rate limits", .japanese: "レート制限", .korean: "속도 제한"],
        .primaryWindow: [.traditionalChinese: "主要視窗", .english: "Primary window", .japanese: "プライマリウィンドウ", .korean: "기본 창"],
        .secondaryWindow: [.traditionalChinese: "次要視窗", .english: "Secondary window", .japanese: "セカンダリウィンドウ", .korean: "보조 창"],
        .accountID: [.traditionalChinese: "帳戶 ID", .english: "Account ID", .japanese: "アカウントID", .korean: "계정 ID"],
        .email: [.traditionalChinese: "Email", .english: "Email", .japanese: "メール", .korean: "이메일"],
        .userID: [.traditionalChinese: "使用者 ID", .english: "User ID", .japanese: "ユーザーID", .korean: "사용자 ID"],
        .available: [.traditionalChinese: "可用", .english: "Available", .japanese: "利用可能", .korean: "사용 가능"],
        .applicable: [.traditionalChinese: "適用", .english: "Applicable", .japanese: "適用可能", .korean: "적용 가능"],
        .local: [.traditionalChinese: "本機", .english: "Local", .japanese: "ローカル", .korean: "로컬"],
        .cloud: [.traditionalChinese: "雲端", .english: "Cloud", .japanese: "クラウド", .korean: "클라우드"],
        .allowance: [.traditionalChinese: "流量額度", .english: "Allowance", .japanese: "転送枠", .korean: "할당량"],
        .networkIn: [.traditionalChinese: "NetworkIn", .english: "NetworkIn", .japanese: "NetworkIn", .korean: "NetworkIn"],
        .networkOut: [.traditionalChinese: "NetworkOut", .english: "NetworkOut", .japanese: "NetworkOut", .korean: "NetworkOut"],
        .publicIP: [.traditionalChinese: "公網 IP", .english: "Public IP", .japanese: "パブリックIP", .korean: "공인 IP"],
        .bundle: [.traditionalChinese: "Bundle", .english: "Bundle", .japanese: "バンドル", .korean: "번들"],
        .specification: [.traditionalChinese: "規格", .english: "Specification", .japanese: "仕様", .korean: "사양"],
        .system: [.traditionalChinese: "系統映像", .english: "Blueprint", .japanese: "ブループリント", .korean: "블루프린트"],
        .endpoint: [.traditionalChinese: "管理 API", .english: "Management API", .japanese: "管理API", .korean: "관리 API"],
        .state: [.traditionalChinese: "狀態", .english: "State", .japanese: "状態", .korean: "상태"],
        .period: [.traditionalChinese: "統計期間", .english: "Period", .japanese: "集計期間", .korean: "집계 기간"],
        .limited: [.traditionalChinese: "受限", .english: "Limited", .japanese: "制限中", .korean: "제한됨"],
        .ok: [.traditionalChinese: "正常", .english: "OK", .japanese: "正常", .korean: "정상"],
        .monthly: [.traditionalChinese: "每月", .english: "mo", .japanese: "月", .korean: "월"],
    ]

    static func text(_ key: CopyKey, _ language: AppLanguage) -> String {
        table[key]?[language] ?? table[key]?[.english] ?? key.rawValue
    }

    static func providerName(_ id: String, _ language: AppLanguage) -> String {
        switch id {
        case StatusMetricID.codex.rawValue: return text(.codex, language)
        case StatusMetricID.lightsail.rawValue: return text(.lightsail, language)
        case StatusMetricID.yuhaiin.rawValue: return text(.yuhaiin, language)
        case StatusMetricID.cycle.rawValue: return text(.cycle, language)
        default: return id
        }
    }

    static func providerDescription(_ id: String, _ language: AppLanguage) -> String {
        switch id {
        case StatusMetricID.codex.rawValue: return text(.codexDescription, language)
        case StatusMetricID.lightsail.rawValue: return text(.lightsailDescription, language)
        case StatusMetricID.yuhaiin.rawValue: return text(.yuhaiinDescription, language)
        case StatusMetricID.cycle.rawValue: return text(.cycleDescription, language)
        default: return ""
        }
    }

    static func duration(_ seconds: Int, _ language: AppLanguage) -> String {
        let value = max(0, seconds)
        let days = value / 86_400
        let hours = (value % 86_400) / 3_600
        let minutes = (value % 3_600) / 60
        switch language {
        case .traditionalChinese:
            if days > 0 { return String(format: "%d 天 %d 小時", days, hours) }
            if hours > 0 { return String(format: "%d 小時 %d 分", hours, minutes) }
            return String(format: "%d 分", minutes)
        case .japanese:
            if days > 0 { return String(format: "%d日 %d時間", days, hours) }
            if hours > 0 { return String(format: "%d時間 %d分", hours, minutes) }
            return String(format: "%d分", minutes)
        case .korean:
            if days > 0 { return String(format: "%d일 %d시간", days, hours) }
            if hours > 0 { return String(format: "%d시간 %d분", hours, minutes) }
            return String(format: "%d분", minutes)
        case .english:
            if days > 0 { return String(format: "%dd %dh", days, hours) }
            if hours > 0 { return String(format: "%dh %dm", hours, minutes) }
            return String(format: "%dm", minutes)
        }
    }

    static func window(_ seconds: Int?, _ language: AppLanguage) -> String {
        guard let seconds else { return "-" }
        if seconds == 18_000 {
            switch language {
            case .traditionalChinese: return "5 小時額度"
            case .english: return "5-hour quota"
            case .japanese: return "5時間クォータ"
            case .korean: return "5시간 할당량"
            }
        }
        switch language {
        case .traditionalChinese: return seconds % 86_400 == 0 ? "\(seconds / 86_400) 天" : (seconds % 3_600 == 0 ? "\(seconds / 3_600) 小時" : "\(seconds) 秒")
        case .japanese: return seconds % 86_400 == 0 ? "\(seconds / 86_400)日" : (seconds % 3_600 == 0 ? "\(seconds / 3_600)時間" : "\(seconds)秒")
        case .korean: return seconds % 86_400 == 0 ? "\(seconds / 86_400)일" : (seconds % 3_600 == 0 ? "\(seconds / 3_600)시간" : "\(seconds)초")
        case .english: return seconds % 86_400 == 0 ? "\(seconds / 86_400) day" : (seconds % 3_600 == 0 ? "\(seconds / 3_600) hour" : "\(seconds) sec")
        }
    }
}
