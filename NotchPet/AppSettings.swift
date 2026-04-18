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
}

// MARK: - Settings

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var soundVolume: Float = 0.8
    @Published var shakeEnabled: Bool = true
    @Published var language: AppLanguage = .zh

    private var sinks = Set<AnyCancellable>()

    private init() {
        let d = UserDefaults.standard
        if d.object(forKey: "soundVolume") != nil { soundVolume = d.float(forKey: "soundVolume") }
        if d.object(forKey: "shakeEnabled") != nil { shakeEnabled = d.bool(forKey: "shakeEnabled") }
        if let raw = d.string(forKey: "language"), let l = AppLanguage(rawValue: raw) { language = l }

        $soundVolume.dropFirst().sink { UserDefaults.standard.set($0, forKey: "soundVolume") }.store(in: &sinks)
        $shakeEnabled.dropFirst().sink { UserDefaults.standard.set($0, forKey: "shakeEnabled") }.store(in: &sinks)
        $language.dropFirst().sink { UserDefaults.standard.set($0.rawValue, forKey: "language") }.store(in: &sinks)
    }
}
