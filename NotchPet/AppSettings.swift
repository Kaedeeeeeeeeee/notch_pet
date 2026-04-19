import Combine
import Foundation

// MARK: - Language

enum AppLanguage: String, CaseIterable {
    case zh, ja, en

    var displayName: String {
        switch self {
        case .zh: return "中文"
        case .ja: return "日本語"
        case .en: return "English"
        }
    }
}

// MARK: - Localized strings

extension AppLanguage {
    private func pick(_ zh: String, _ ja: String, _ en: String) -> String {
        switch self { case .zh: return zh; case .ja: return ja; case .en: return en }
    }

    // Settings
    var settingsTitle: String { pick("设置", "設定", "Settings") }
    var quitApp: String { pick("退出 Notch Pet", "Notch Pet を終了", "Quit Notch Pet") }
    var volumeLabel: String { pick("音量", "音量", "Volume") }
    var shakeLabel: String { pick("震动效果", "振動効果", "Shake") }
    var languageLabel: String { pick("语言", "言語", "Language") }

    // Stages
    var stageEgg: String { pick("たまご", "たまご", "Egg") }
    var stageChild: String { pick("幼年期", "幼年期", "Child") }
    var stageAdult: String { pick("成熟期", "成熟期", "Adult") }
    var stageElder: String { pick("老年期", "老年期", "Elder") }
    var stageDeparted: String { pick("告别", "お別れ", "Departed") }

    // Vitals
    var hungerLabel: String { pick("おなか", "おなか", "Hunger") }
    var happyLabel: String { pick("ごきげん", "ごきげん", "Mood") }
    var weightLabel: String { pick("体重", "体重", "Weight") }

    // Actions
    var feedAction: String { pick("喂食", "えさ", "Feed") }
    var playAction: String { pick("玩耍", "あそぶ", "Play") }
    var medicineAction: String { pick("吃药", "くすり", "Medicine") }
    var cleanAction: String { pick("扫除", "そうじ", "Clean") }

    // Sleep
    var petSleeping: String { pick("宠物睡着了", "ペットは寝ています", "Pet is sleeping") }

    // Departed → reborn confirmation
    func departFarewellTitle(name: String) -> String {
        pick("\(name) 离开了…", "\(name) は旅立ちました…", "\(name) has departed…")
    }
    var departFarewellBody: String {
        pick("谢谢你的陪伴。\n新的生命正在等待你。",
             "一緒にいてくれてありがとう。\n新しい命があなたを待っています。",
             "Thank you for the time together.\nA new life awaits you.")
    }
    var departRebornButton: String { pick("迎接新生命", "新しい命を迎える", "Welcome New Life") }

    // Memorial card
    var memorialTitle: String { pick("纪念", "記念", "Memorial") }
    func memorialLivedDays(days: Int) -> String {
        pick("活了 \(days) 天",
             "\(days) 日間生きた",
             "Lived \(days) day\(days == 1 ? "" : "s")")
    }
    var memorialFedLabel: String        { pick("喂食", "えさ", "Fed") }
    var memorialPlayedLabel: String     { pick("玩耍", "あそび", "Played") }
    var memorialWeightLabel: String     { pick("体重", "体重", "Weight") }
    var memorialGenerationLabel: String { pick("代", "世代", "Gen") }
    var memorialWeightUnit: String      { pick("g", "g", "g") }
    var memorialSaveImage: String       { pick("保存图像", "画像を保存", "Save Image") }

    // Shop
    var shopTitle: String { pick("商店", "ショップ", "Shop") }
    var roomsTab: String { pick("房间", "部屋", "Rooms") }
    var furnitureTab: String { pick("家具", "家具", "Furniture") }
    var clothesTab: String { pick("衣服", "服", "Clothes") }
    var buyButton: String { pick("购买", "購入", "Buy") }
    var equipButton: String { pick("装备", "装備", "Equip") }
    var inUse: String { pick("使用中", "使用中", "In Use") }
    var owned: String { pick("已拥有", "所持", "Owned") }
    var putAway: String { pick("収起", "しまう", "Remove") }
    var placeButton: String { pick("放置", "配置", "Place") }
    var placed: String { pick("已放置", "配置済み", "Placed") }
    var floorLeft: String { pick("左地板", "左床", "Left") }
    var floorRight: String { pick("右地板", "右床", "Right") }
    var wallBack: String { pick("后墙", "壁", "Back") }
    var comingSoon: String { pick("敬请期待", "お楽しみに", "Coming Soon") }
    var moreClothes: String { pick("更多衣服即将上线！", "新しい服がもうすぐ！", "More clothes coming soon!") }

    // Onboarding (first-run)
    var onboardingStep1Title: String { pick("Notch Pet 住在这里", "Notch Pet はここに住んでいます", "Notch Pet lives here") }
    var onboardingStep1Body:  String {
        pick("它住在你 Mac 的刘海区域。\n点一下就能看看它。",
             "Mac のノッチに住んでいます。\nタップして様子を見よう。",
             "It lives in your Mac's notch.\nClick any time to check in.")
    }
    var onboardingStep2Title: String { pick("这是你的蛋", "これはあなたのたまご", "Meet your egg") }
    var onboardingStep2Body:  String {
        pick("再过一会儿它就会孵化。\n一代又一代陪伴你。",
             "もうすぐふ化します。\n世代を超えて一緒に。",
             "It'll hatch soon—and stay\nwith you across generations.")
    }
    var onboardingStep3Title: String { pick("记得照顾它", "お世話を忘れずに", "Care for it") }
    var onboardingStep3Body:  String {
        pick("饥饿和心情都会慢慢降低。\n喂食、玩耍、打扫就好。",
             "おなかときげんは少しずつ下がります。\nえさ・あそぶ・そうじで OK。",
             "Hunger and mood drop over time.\nFeed, play, and clean to keep up.")
    }
    var onboardingNextButton:  String { pick("下一步", "つぎへ", "Next") }
    var onboardingStartButton: String { pick("开始", "はじめる", "Let's begin") }

    // Marriage + breeding
    var marriageTitle: String        { pick("结婚", "結婚", "Marriage") }
    var marriageShowQRTab: String    { pick("我的请柬", "私の招待状", "My Invite") }
    var marriageScanQRTab: String    { pick("扫描请柬", "招待状をスキャン", "Scan Invite") }
    var marriageShowQRHint: String {
        pick("让对方扫描此二维码",
             "この QR を相手にスキャンしてもらう",
             "Have your partner scan this code")
    }
    var marriageScanHint: String {
        pick("准备好对方手机/屏幕上的二维码，\n然后打开摄像头对准它",
             "相手の QR を準備し、\nカメラで読み取ってください",
             "Have your partner's QR ready,\nthen open the camera to scan it")
    }
    var marriageScanButton: String      { pick("打开摄像头", "カメラを開く", "Open Camera") }
    var marriageScanFailed: String      { pick("无效的二维码", "無効な QR", "Invalid QR code") }
    var marriageScanCameraError: String { pick("无法访问摄像头", "カメラにアクセスできません", "Camera unavailable") }
    var marriageScanWindowTitle: String { pick("扫描结婚二维码", "結婚 QR をスキャン", "Scan Marriage QR") }
    var marriageConfirmed: String       { pick("结婚成功！", "結婚成立！", "Married!") }
    var marriageIneligible: String {
        pick("你的宠物还未成年，暂时不能结婚",
             "このペットはまだ結婚できません",
             "Your pet isn't eligible to marry yet")
    }
    var confirmClose: String            { pick("好的", "閉じる", "Done") }

    // Family farewell + memorial lineage
    var familyFarewellTitle: String {
        pick("一家人最后的时光",
             "家族最後のとき",
             "One last day as a family")
    }
    var memorialParentsLabel: String    { pick("父母", "両親", "Parents") }

    // Account / Apple sign-in
    var accountSectionLabel: String    { pick("账号", "アカウント", "Account") }
    var signInWithAppleLabel: String   { pick("连接 Apple ID", "Apple ID で連携", "Connect Apple ID") }
    var signedInAsLabel: String        { pick("已登录", "ログイン中", "Signed in") }
    var signOutLabel: String           { pick("退出登录", "ログアウト", "Sign out") }
    var anonymousUserLabel: String     { pick("本地用户", "ローカルユーザー", "Local user") }
    var syncCloudHint: String {
        pick("登录后跨设备同步宠物与纪念册",
             "ログインして端末間でペットと記念帳を同期",
             "Sign in to sync your pet and memorial book across devices")
    }

    // Memorial book
    var memorialBookTitle: String      { pick("纪念册", "記念帳", "Memorial Book") }
    var memorialBookOpenLabel: String  { pick("打开纪念册", "記念帳を開く", "Open Memorial Book") }
    var memorialBookEmpty: String {
        pick("还没有离世的宠物。\n连接 Apple ID 以跨设备保留纪念。",
             "まだ別れたペットはいません。\nApple ID で端末間保存を有効に。",
             "No departed pets yet.\nConnect Apple ID to preserve them across devices.")
    }
    var memorialBookLocalOnly: String {
        pick("本地记录（登录 Apple ID 后可跨设备）",
             "ローカル記録（Apple ID でクラウド同期可）",
             "Local only — sign in to sync across devices")
    }
}

// MARK: - Settings

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var soundVolume: Float = 0.8
    @Published var shakeEnabled: Bool = true
    @Published var language: AppLanguage = .zh
    @Published var hasCompletedOnboarding: Bool = false

    // v2 cloud auth state. Reflects Supabase session; not a source of
    // truth (AuthService owns that) but convenient for SwiftUI bindings
    // and last-sync indicators in Settings.
    @Published var isAppleLinked: Bool = false
    @Published var userEmail: String? = nil
    @Published var lastSyncAt: Date? = nil

    private var sinks = Set<AnyCancellable>()

    private init() {
        let d = UserDefaults.standard
        if d.object(forKey: "soundVolume") != nil { soundVolume = d.float(forKey: "soundVolume") }
        if d.object(forKey: "shakeEnabled") != nil { shakeEnabled = d.bool(forKey: "shakeEnabled") }
        if let raw = d.string(forKey: "language"), let l = AppLanguage(rawValue: raw) { language = l }
        if d.object(forKey: "hasCompletedOnboarding") != nil {
            hasCompletedOnboarding = d.bool(forKey: "hasCompletedOnboarding")
        }
        if d.object(forKey: "isAppleLinked") != nil {
            isAppleLinked = d.bool(forKey: "isAppleLinked")
        }
        userEmail = d.string(forKey: "userEmail")

        $soundVolume.dropFirst().sink { UserDefaults.standard.set($0, forKey: "soundVolume") }.store(in: &sinks)
        $shakeEnabled.dropFirst().sink { UserDefaults.standard.set($0, forKey: "shakeEnabled") }.store(in: &sinks)
        $language.dropFirst().sink { UserDefaults.standard.set($0.rawValue, forKey: "language") }.store(in: &sinks)
        $hasCompletedOnboarding.dropFirst()
            .sink { UserDefaults.standard.set($0, forKey: "hasCompletedOnboarding") }
            .store(in: &sinks)
        $isAppleLinked.dropFirst()
            .sink { UserDefaults.standard.set($0, forKey: "isAppleLinked") }
            .store(in: &sinks)
        $userEmail.dropFirst()
            .sink { UserDefaults.standard.set($0, forKey: "userEmail") }
            .store(in: &sinks)
    }
}
