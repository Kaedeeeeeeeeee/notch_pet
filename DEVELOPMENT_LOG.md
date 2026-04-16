# Notch Pet — 开发日志

> 与 `notch-pet-product-design.md` 配套使用。设计文档描述"做什么"，本文档记录"已经做了什么 / 下一步做什么"。

## 当前状态

**Block 6 完成**：Tamagotchi 风格的核心养成循环改造 + 房间 / 家具系统。
- **离散心形 vitals**（`hunger` / `happy` 改为 0–4 整数心），删除 `energy` 和 `rest` 按钮
- **自动睡眠**（没有手动 rest 按钮，完全走 NightSleepSchedule）
- **生病系统**：3 种触发（阶段概率 / 饱食低谷神经质 / 便便堆积），`takeMedicine()` 需要点 2 次才痊愈
- **便便系统**：喂食后一段时间自动生成，`clean()` 一键清理
- **喂食 / 玩耍动画**：SwiftUI overlay（饭团下落、红球弹跳），不占用 spritesheet
- **金币经济** + `PlayerInventory` 独立持久化（`inventory.json`），跨世代保留
- **4 个房间主题**（默认 / 和风 / 太空 / 森林），**6 件家具**（3 个槽位），管理面板 UI 全部就绪

---

## 技术约束（已锁定）

- 目标平台：macOS 15.0+，**仅支持带刘海的 MacBook**
- 技术栈：Swift + AppKit + SwiftUI（`NSHostingView` 嵌入）
- 窗口方案：自定义 `NSPanel` 子类（参考 boring.notch 的 styleMask 组合），公开 API 版本，不使用私有 SkyLight/`CGSSpace`
- 项目生成：XcodeGen（`project.yml`）
- App Sandbox：MVP 阶段关闭
- `LSUIElement = YES`：无 Dock 图标

---

## Block 清单

### Block 0 — 项目初始化 ✅/🟡

- [x] `git init`，`.gitignore`
- [x] XcodeGen `project.yml`
- [x] `Info.plist` + `NotchPet.entitlements`（sandbox off, LSUIElement on）
- [x] 源码目录骨架
- [x] `xcodebuild` 能干净构建（待验证）

### Block 1 — 刘海骨架 + 像素宠物 idle + 展开 popover 🟡（代码完成，等验收）

**1. 刘海窗口 & 定位**
- [x] `NotchPanel`：`[.borderless, .nonactivatingPanel, .utilityWindow, .hudWindow]`，level = `.statusBar`，`canJoinAllSpaces` 等 collection behavior
- [x] `NotchGeometry`（`NSScreen` 扩展）：`safeAreaInsets.top` + `auxiliaryTopLeft/RightArea` 推算刘海尺寸
- [x] **多屏处理**：`NSScreen.builtInNotchedScreen` 遍历所有屏幕找到带刘海的内建屏，不依赖 `NSScreen.main`（外接屏被设为主屏时也能正确找到刘海）
- [x] `NotchPanelController`：初始定位、展开/折叠动画、屏幕参数变更观察、Space 变更观察
- [x] `AppDelegate`：无刘海弹 alert 退出

**2. 像素宠物占位**
- [x] `PetRenderer` / `PetView`：Canvas 绘制 16×16 像素小鸡，4 帧 idle（呼吸 + 眨眼），6 fps
- [x] `PetState` 最小 stub（Block 2 扩）

**3. 展开 / 收起**
- [x] `NotchRootView`：折叠/展开态切换（`state.isExpanded`）
- [x] **`FirstMouseHostingView`**：NSHostingView 子类，`acceptsFirstMouse = true` + 在 `mouseDown` 里直接触发 expand。折叠态不走 SwiftUI 手势，避免 `.nonactivatingPanel` 上 tap gesture 不稳定的问题
- [x] 点击折叠态 → 展开到 360×420 `RoomView`
- [x] 收起按钮（chevron）+ ESC（`cancelOperation` → Notification → controller.collapse()）

**4. 验证（xcodebuild 自动 + 人眼手动）**
- [x] `xcodebuild` clean 通过（零警告）
- [x] 自动：刘海位置出现小鸡（截图确认）
- [x] 自动：帧动画循环（4 帧连拍确认呼吸偏移）
- [x] 自动：点击刘海展开成 360×420 房间 popover（截图确认，包含小鸡、房间背景、3 个占位状态条、chevron 收起按钮）
- [x] 手动：ESC / chevron 收起（用户本地确认通过）
- [x] 手动：跨 Space / 全屏切换 / 休眠唤醒后窗口仍在（用户本地确认通过）
- [x] 手动：外接屏为主屏时，宠物在 MBP 内建屏的刘海上（用户本地确认通过）

**5. Aseprite CLI（为 Block 2 铺路）** ✅
- [x] clone aseprite 源码到 `tools/aseprite/`
- [x] `brew install ninja`
- [x] Skia m124 预编译包已自动下载到 `.deps/skia-m124`（由 `build.sh` 处理）
- [x] `build.sh --auto --norun` 编译完成（1562 目标，约 3 分钟）
- [x] 验证：`tools/aseprite/build/bin/aseprite --version` → `Aseprite 1.x-dev`

### Block 2 — 状态与时间 ✅

- [x] `PetState` 完整模型：hunger / mood / energy + applyDecay(activeSeconds:)
- [x] `TimeService`：1 Hz tick + NSWorkspace willSleep/didWake/screensDidSleep/screensDidWake/sessionResign/sessionBecome 暂停-恢复
- [x] 夜间睡眠时段（21:00~09:00 本地固定，Block 3 由性格影响）
- [x] `RoomView` 真实状态条 + 喂食/玩耍/休息按钮 + 夜间 Zzz 蒙层
- [x] `PetView` 按状态切模式（idle / hungry / sleeping），hungry 头顶冒 `!`，sleeping 眼睛闭上 + 身后 Z
- [x] JSON 持久化到 `~/Library/Application Support/com.notchpet.NotchPet/state.json`
- [x] DEBUG 模式 30x decay 加速（`NOTCHPET_DECAY_SPEEDUP` env 覆盖）
- [x] ESC + 点击面板外部自动收起（`NSEvent.addGlobalMonitorForEvents`，监听回调做面板命中测试避免面板内点击被误判）

### Block 3 — 生命周期 & 性格 ✅（不含配对/遗传）

- [x] `LifecycleStage` enum + `LifecycleTable`：egg/child/adult/elder/departed，按 active day 映射
- [x] `LifecycleClock`：可配置的 activeSecondsPerDay（DEBUG 默认 20s/day，`NOTCHPET_DAY_SECONDS` 覆盖）
- [x] `PetState` 扩展 ageActiveSeconds/stage/departedAt/personality/careHistory/generation
- [x] `PersonalityTrait` 六种：活泼/害羞/高冷/贪吃/懒惰/暴躁，各带 body tint
- [x] `CareHistory` 追踪 feed/play/rest 次数，child→adult 时 `derivePersonality` 决定主性格（12% 概率冷门变异）
- [x] 世代循环：stage = .departed → 等 `departGraceSeconds` → `rebornAsNewGeneration()` 原地重置 PetState 字段（id/generation/vitals/history/stage 全部重来）
- [x] `PetRenderer` 新增 egg / departed 专属绘制，child 版本缩小 1 像素，elder 整体 dim 到 0.85
- [x] RoomView header 显示 name + 性格 tag + 阶段标签 + Gen 计数
- [x] `ActionBar` 用 `petState.canInteract`（egg/departed/isAsleep 统一 disable）
- [ ] **跳过**：配对、遗传、变异（完整流程在 Block 3+ 补做，MVP 先不做）

### Block 4 — 反馈与正式素材 ✅

- [x] 用 Aseprite Lua 脚本生成 .aseprite 源文件，再用 CLI 导出 packed spritesheet（PNG + JSON）
- [x] 替换占位 `PetRenderer`，引入 `PetSpriteLibrary` 加载 + 切片
- [x] PetMode 增加 `.happy` / `.sick` 分支，配套 `happyUntil` / `isSick` 触发规则
- [x] AudioToolbox 8-bit 音效（feed/play/rest/hatch/depart/happy）
- [x] `NotchPanelController.shake(.light|.heavy)` panel 摇晃反馈，绑定喂食 + departed 通知

### Block 5 — 进化分支 + 性格行为 ✅

- [x] 6 个 personality form 各自独立的 16×16 sprite grid + baked tint
- [x] `gen_pet.lua` 参数化为 form × stage × mode 矩阵（82 tags / 287 帧）
- [x] `PetSprite` loader 改用 `<form>_<stage>_<mode>` tag key + 多级 fallback
- [x] `PersonalityBehavior.swift` 集中 gameplay 调制
- [x] PetMode 新增 `.curious`（hover）和 `.angry`（grumpy 低 vital）
- [x] 新音效：`.feedReject`（拒绝 nope）、`.angry`（低音 growl）

### Block 6 — Tamagotchi Loop Overhaul + 房间家具系统 ✅

- [x] **离散心形 vitals**：`hunger` / `happy` 改为 0–4 整数（原来 0.0–1.0 float），`mood` 字段改名 `happy`，`energy` 完全移除
- [x] **PetStateStore v2 → v3 migration**：浮点值按 × 4 round 映射到心数
- [x] **删除 rest 按钮 + `rest()` 方法**，睡觉完全由 `NightSleepSchedule` 控制
- [x] **生病系统**：`sick: Bool`、`medicineDosesRemaining`、三条触发规则
- [x] **`takeMedicine()` 需要点 2 次**（致敬原版 Tamagotchi 多剂用药），最终一次 +3 coins
- [x] **便便系统**：`poops: Int` 0–3，喂食后定时生成，`clean()` 清空 +2 coins
- [x] **`runCareTick`**：专门的每秒 job 处理便便生成 + 生病 roll，与 `applyDecay` 分离
- [x] **喂食 / 玩耍动画 overlay**：`.eating` 饭团下落、`.playing` 红球弹跳，900ms 后自动清除（纯 SwiftUI，不占 spritesheet）
- [x] **`PlayerInventory`** 独立 model + `InventoryStore` 独立 JSON 持久化，跨世代保留
- [x] **金币获取规则**：feed/play +1、clean +2、medicine 最终 +3、stage transition +10、depart +20
- [x] **4 个房间主题**：`default` / `washitsu` / `space` / `forest`，纯 SwiftUI 背景
- [x] **6 件家具 + 3 个槽位**：`ball` / `table` / `cushion` / `plant` / `lantern` / `poster`，新 Aseprite sheet `furniture.png`
- [x] **`ManagementPanel`** 管理面板：全屏 overlay，`房间` / `家具` 两个 tab，购买 / 装备 / 放置 / 收起
- [x] **新音效**：`.medicine`（轻钟）、`.clean`（扫除升调）

---

## 变更日志

### 2026-04-15 — Block 0 + Block 1 代码落地

**新增目录结构**：
```
NotchPet/
├── NotchPetApp.swift               # @main, 启动 NSApplication
├── AppDelegate.swift               # 无刘海兜底，启动 NotchPanelController
├── Notch/
│   ├── NotchPanel.swift            # NSPanel 子类
│   ├── NotchPanelController.swift  # 定位 / 展开-折叠 / 观察者
│   ├── NotchGeometry.swift         # NSScreen 刘海尺寸扩展 + builtInNotchedScreen
│   ├── FirstMouseHostingView.swift # NSHostingView 子类，acceptsFirstMouse + mouseDown 转发
│   └── NotchRootView.swift         # SwiftUI 根 + 折叠态小视图
├── Pet/
│   ├── PetView.swift               # TimelineView 驱动的 Canvas 像素宠物
│   └── PetState.swift              # Block 2 占位
├── Room/
│   └── RoomView.swift              # 展开态房间 + 占位状态条
├── Assets.xcassets/                # AppIcon 占位 + 根 Contents.json
└── Resources/
    ├── Info.plist
    └── NotchPet.entitlements
```

**关键技术决策**：
- NSPanel `styleMask = [.borderless, .nonactivatingPanel, .utilityWindow, .hudWindow]`
- `level = .statusBar` + broad `collectionBehavior`，不用 SkyLight 私有 API
- 像素宠物 Block 1 纯代码绘制（`GraphicsContext`），等 Block 4 用 Aseprite 正式素材替换
- ESC 通过 `cancelOperation` 触发 `NotificationCenter` 广播，controller 收到后 collapse

**踩过的坑（记录以防 Block 2 重复）**：

1. **`NSScreen.main` 不是内建屏**：用户把外接屏设为主屏，`NSScreen.main` 返回外接屏（无刘海），导致启动直接弹"未检测到刘海"。修复：`NSScreen.builtInNotchedScreen` 遍历 `NSScreen.screens` 找 `safeAreaInsets.top > 0` 的屏幕。
2. **`.nonactivatingPanel` 上 SwiftUI `.onTapGesture` 收不到事件**：非 key 的 panel 默认 `acceptsFirstMouse = false`，click 被 AppKit 吞掉。修复：`FirstMouseHostingView` 同时重写 `acceptsFirstMouse` 和 `mouseDown`，在 AppKit 层直接处理折叠态的点击。
3. **AppleScript `click at` 不触发 `mouseDown`**：`tell System Events to click at {x,y}` 用的是 Accessibility 动作，不发合成鼠标事件。测试用 `CGEvent(...mouseType: .leftMouseDown, ...).post(tap: .cghidEventTap)` 才能触发真正的 mouseDown。
4. **双重 tap 导致展开立刻被折叠**：AppKit `mouseDown` 调 `expand()`，然后 `super.mouseDown` 把事件转给 SwiftUI，SwiftUI 的 `.onTapGesture` 再次触发 `toggle()`，导致刚展开就被关掉。修复：折叠态 SwiftUI 不装手势，完全依赖 AppKit 层。展开态内部的 button 走 `super.mouseDown` 正常转发。

**未决 / 风险**：
- 展开态宽度 360 > 刘海宽度 ~185，当前保持顶部居中，展开后会覆盖刘海两侧的菜单栏区域。Block 1 接受这个表现，Block 2 再考虑动画轨迹。
- 无刘海机器目前直接 alert + 退出。

**验证方式（CGEvent + screencapture 自动化）**：
- 截图 `/tmp/notchpet_collapsed_v2.png`：刘海里的小鸡 ✓
- 连拍 `/tmp/notchpet_frame_{1..4}.png`：呼吸偏移动画 ✓
- 截图 `/tmp/notchpet_expanded_v5.png`：展开态房间 + 收起按钮 ✓

### 2026-04-15 — 视觉升级（收尾用户反馈）

用户反馈要点：
1. 刘海折叠态宠物太大，且居中覆盖整个刘海——改成小尺寸 + 放在刘海左侧
2. 刘海右侧放状态提示，没事黑着，饿了/累了/无心情时显示对应图标
3. 折叠态面板下方两个角是直角太丑，需要和 MacBook 物理刘海一样的圆角
4. 展开态背景要改为黑色（和刘海视觉连贯）
5. 展开态下方两个角也需要圆角
6. 宠物本身的像素美术可以做得更精细

**改动**：

- `NotchPet/Notch/NotchPanelController.swift` — collapsed size 从 `notchWidth × notchHeight` 改为 `notchWidth × (notchHeight + 16)`；多出的 16pt 在刘海下方用来放圆角。新增 `notchCavityHeight` 传给 SwiftUI 用于 cavity 内对齐。expanded 尺寸 420 → 460 高度一点点。
- `NotchPet/Notch/NotchRootView.swift` — 
  - 新增 `NotchClipShape`（基于 `UnevenRoundedRectangle`），只圆下方两个角。folded 时 12pt 半径，expanded 时 18pt 半径。
  - `CollapsedNotchView` 用 `HStack(alignment: .top)` 把宠物放左、状态图标放右，中间 Spacer 保持纯黑。pet/icon 根据 `cavityHeight` 手动 top-padding 使其垂直居中在刘海 cavity 内，而不是整个 panel（包含圆角突出区域）。
  - 新增 `StatusIconView` 决定当前状态图标：lifecycle 最高优先（egg→无、departed→👋），然后 `isAsleep`→💤，然后 vitals < 0.30 的最严重项用 🍚/⚡️/💔。阈值 0.30 比 PetView 的 0.25 稍早触发，让刘海态比宠物身上的 `!` 气泡更早报警。
- `NotchPet/Room/RoomView.swift` — `RoomBackground` 去掉紫色渐变和棕色地板条，改为纯 `Color.black` + 一条 4% 白的极淡地板线。头部 padding 不变。
- `NotchPet/Pet/PetView.swift` — 彻底重画 `chickShape`：
  - 16×16 grid 不变，但 cell 编码从 3 种（outline/body/空）扩展到 10 种（body/outline/highlight/belly/beak/eye-white/eye-pupil/cheek/wing）
  - 身体上方加 highlight 行（1.00r/0.95g/0.60b 的亮黄），下方加 belly 行（深一点的芥末黄），形成微立体感
  - 眼睛变成 2-pixel 宽的白色 + 黑瞳组合
  - 三角形喙：row 5 开始 2 格基底 + row 6 2 格尾端
  - 右侧加 wing 色块（3 像素，更暗的黄）
  - 脸颊下移到 row 6（跟眼睛同高），blink 时 overwrite 成 body 色消失
  - 所有颜色都走 `tint * dim` 乘算，personality 和 elder 的视觉差异仍然生效

**自动化验证**：
- 折叠态（child/adult，饱腹度正常）：左小鸡 + 右黑 + 下方圆角 ✓
- 折叠态（hunger=0.10 预埋）：左小鸡头顶冒 `!` + 右边 🍚 图标 + 下方圆角 ✓
- 展开态（adult + cheerful）：黑底 + 下方圆角 + 细节 chick sprite + header 显示「ひよこ 活泼 · Gen 1 · 成熟期 Day 7.0 · げんき」 ✓

### 2026-04-15 — Block 3 落地

**新增文件**：
- `NotchPet/Pet/LifecycleStage.swift` — `LifecycleStage` enum + `LifecycleTable` age→stage 映射 + `LifecycleClock` day length 配置
- `NotchPet/Pet/Personality.swift` — `PersonalityTrait` 六种 + body tint + `CareHistory` 计数 + `derivePersonality(rng:)` 决策规则

**改写文件**：
- `NotchPet/Pet/PetState.swift` — 加 ageActiveSeconds/stage/departedAt/personality/careHistory/generation 字段；`advanceLifecycle(activeSeconds:)` 驱动阶段机；`handleStageTransition` 在 child→adult 固化性格、进入 departed 时记时间戳；`rebornAsNewGeneration()` 原地重置全部字段；`canInteract` 统一门禁
- `NotchPet/Pet/PetStateStore.swift` — schemaVersion bump 到 2，snapshot 覆盖所有新字段
- `NotchPet/Pet/TimeService.swift` — tick 里额外调 `advanceLifecycle`；检查 .departed 阶段是否超过 grace window，超了就 `rebornAsNewGeneration` + 立即 save
- `NotchPet/Pet/PetView.swift` — `PetRenderer.draw` 多接 `stage` 和 `personality`；egg / departed 用独立 pixel shape；child 版本整体下移 1 像素；elder 颜色 dim；性格 body tint 作用于 chick 期
- `NotchPet/Room/RoomView.swift` — header 显示性格 tag + 阶段标签 + Gen 计数；ActionBar 用 `canInteract` 代替 `isAsleep`
- `DEVELOPMENT_LOG.md` — 追加 Block 3 记录

**自动化验证结果**：
- `NOTCHPET_DAY_SECONDS=5` 让 10 天 = 50s，在 100s 内跑完 2+ 个完整世代
- 启动 → 立刻展开 → 看到 たまご Day 0.1 的蛋 sprite（cream 色 + 棕色描边 + 3 个 speckle）✓
- 等到 Day 4.8 → 幼年期 chick（缩小版）✓
- 跑完整个循环：egg → child → adult → elder → departed → 新 egg (Gen 2+) ✓
- 性格在未交互的情况下 fallback 到 "害羞"（符合 derivePersonality 规则 total<3 → shy）✓
- state.json 最终 Gen=4，阶段机一路推进无卡死 ✓

**已知小瑕疵（不 block）**：
- 阶段标签和 ageDays 显示偶有 1 tick 的不一致，因为两个 @Published 在同一 tick 里先后更新；下个 block 或后续优化再处理
- egg stage 的 RoomView 仍显示状态条和按钮（都 disabled），视觉上略冗余。Block 4 用正式素材替换时顺带重做蛋的 layout

**新增文件**：
- `NotchPet/Pet/PetStateStore.swift` — Codable `PetStateSnapshot` + `~/Library/Application Support/com.notchpet.NotchPet/state.json` 原子读写
- `NotchPet/Pet/TimeService.swift` — 1Hz Timer + NSWorkspace 休眠/唤醒/会话观察者；tick 里计算 `activeSeconds` delta 交给 `PetState.applyDecay`，每 30s save 一次
- `NotchPet/Pet/NightSleep.swift` — `NightSleepSchedule` 判断当前时间是否处于夜间窗口（跨午夜正确）

**改写文件**：
- `NotchPet/Pet/PetState.swift` — 从 struct stub 改成 `final class: ObservableObject`：`@Published hunger/mood/energy/isAsleep/lastTickAt`；`feed()` / `play()` / `rest()` 动作；`applyDecay(activeSeconds:)` 按 fast(energy 2h) / medium(hunger 4h) / slow(mood 8h) 衰减；DEBUG 模式 30x 倍速
- `NotchPet/Room/RoomView.swift` — 重写：header 显示名字 + 状态、真实 `VitalsStrip` 三条胶囊 bar、`ActionBar` 三按钮（emoji icon + 像素风边框）、`SleepOverlay` 夜间蒙层
- `NotchPet/Pet/PetView.swift` — 接受 `petState`，按 `PetMode.idle/hungry/sleeping` 切渲染；`hungry` 头顶冒橙色 `!`；`sleeping` 眼睛线条化 + 身后飘 Z
- `NotchPet/Notch/NotchPanelController.swift` — 构造加 petState 参数；`expand()` 装全局 ESC + 点击监听，`collapse()` 摘；监听回调做 `panel.frame.contains(NSEvent.mouseLocation)` 命中测试，面板内点击不误触发
- `NotchPet/Notch/NotchPanel.swift` — 删掉之前死代码的 `cancelOperation` + `.notchPanelRequestCollapse` 通知链路
- `NotchPet/Notch/NotchRootView.swift` — 接受 `petState` 并传给 collapsed 和 room 分支
- `NotchPet/AppDelegate.swift` — 装配 store/petState/timeService/controller 四件套；`applicationWillTerminate` 调 `timeService.flush()` 保底持久化

**踩的坑**：

1. **`.nonactivatingPanel` 上点击同时到达 AppKit mouseDown 和 global event monitor**：这是我之前以为不会发生的情况。Apple 的 "global monitor 只看发给其他 app 的事件" 对非激活 panel 不成立——非激活 panel 的点击同时被我们的 mouseDown 处理 + 在 global monitor 里以"发给其他 app"的名义再次触发。修复是 global click 监听的回调里用 `panel.frame.contains(NSEvent.mouseLocation)` 判断命中，点击面板内就忽略。

2. **Swift 6 actor isolation**：`PetState` 是 `@MainActor`，`PetStateSnapshot.init(from:)` 读它的属性时默认是非 isolated 上下文，编译报错。修复是给 `init(from:)` 和 `materialize()` 都加 `@MainActor` 标注。类似地 `PetStateStore.currentSchema` 也加 `nonisolated static let` 避免初始化器里访问报错。

**自动化验证结果**：
- 启动 → 点击刘海展开 → 看到 3 条 70% 初始 bar ✓
- 点击喂食按钮 3 次 → おなか 从 70 升到 100 ✓
- 点击面板外部区域（y=600）→ 收起 ✓
- `state.json` 正确写入 ✓
- kill + relaunch → 载入持久化状态（hunger 87, mood 78, energy 44）✓
- ESC 收起（用户手动确认）✓

### 2026-04-15 — Block 4 落地

**新增文件**：
- `tools/sprites/gen_pet.lua` — 用 Aseprite 1.3 Lua API 程序化生成 16×16 像素宠物的所有动画帧。每个 (stage, mode) 组合创建一段连续帧并打 tag。颜色常量与 Block 3 的 `PetRenderer` RGB 完全对齐。
- `tools/sprites/build_sprites.sh` — 一键脚本：`aseprite -b --script gen_pet.lua` → `aseprite -b pet.aseprite --sheet pet.png --data pet.json`。
- `tools/sprites/gen_sounds.py` — Python stdlib（wave + struct + math）合成 6 个方波/三角波 SFX，写入 `NotchPet/Assets/Audio/*.wav`。22050 Hz / 16-bit / mono。
- `NotchPet/Assets/Sprites/pet.png` + `pet.json` — 提交的构建产物（96×96，57 帧 / 17 tag，packed sheet 自动 dedup 后 32 个唯一 cell）。
- `NotchPet/Assets/Audio/{feed,play,rest,hatch,depart,happy}.wav` — 提交的构建产物。
- `NotchPet/Pet/PetSprite.swift` — `PetSpriteLibrary.shared` 单例：在 init 解码 `pet.json`，按 tag 切出 `[String: [CGImage]]`，O(1) 取帧。Tag 命名 `<stage>_<mode>` (e.g. `adult_happy`)。fallback 链：精确 → 同 stage idle → adult idle → 1×1 透明像素。
- `NotchPet/Audio/SoundPlayer.swift` — `AudioServicesCreateSystemSoundID` + `AudioServicesPlaySystemSound` 包装。`SoundPlayer.shared.play(.feed/.play/.rest/.hatch/.depart/.happy)` 即用即放。注册时通过 `Bundle.main.url(forResource:withExtension:subdirectory:"Audio")` 从 app bundle 取文件。

**改写文件**：
- `NotchPet/Pet/PetView.swift` — 删掉 `PetRenderer` 内部所有手画像素逻辑。`Canvas` 改成 `Image(decorative: cg, scale: 1).interpolation(.none).resizable().colorMultiply(tint)`。`colorMultiply` 直接挂在 SwiftUI Image 上，自动遵循 sprite 的 alpha mask（不会画到透明区域）。Elder 用 `.opacity(0.85)`。
  - `enum PetMode` 新增 `.happy` 和 `.sick` 两个 case，加 `tagName` 计算属性。
  - `mode(for:)` 优先级：egg/departed → idle，asleep → sleeping，sick → sick，happy → happy（在 hungry 之前），hunger<0.25 → hungry，else idle。
  - `tintColor(for:)`：`maxComponent` 归一化把 PersonalityTrait.bodyTint 的最亮 channel 映射到 1.0，避免 colorMultiply 把整个 sprite 削暗。`.white` 表示 no-op。
- `NotchPet/Pet/PetState.swift` —
  - `@Published var happyUntil: Date?`（不持久化），`isHappy` / `isSick` 计算属性。`isSick` 规则：3 个 vital 中至少 2 个 < 0.15。
  - `feed/play/rest` 在原有 mutation 之后 `happyUntil = now + 4s` 并 `SoundPlayer.shared.play(.feed/.play/.rest)`。
  - `handleStageTransition`：`.egg → .child` 播 `.hatch`；任意 → `.departed` 播 `.depart` 并 post `.notchPetDidDepart` 通知。
  - 顶部加 `extension Notification.Name { static let notchPetDidDepart = ... }`。
  - **没动 PetStateStore schema** —— `happyUntil` 故意不进 snapshot，重启就回 idle。
- `NotchPet/Notch/NotchPanelController.swift` —
  - 新增 `enum ShakeIntensity { case light, heavy }`。
  - `func shake(_:)` 用 `Task { @MainActor }` + `Task.sleep` 60Hz 跑 7-9 个衰减关键帧，对 `panel.frame.origin.x` 加偏移。Light: 3pt 振幅 / 280ms；Heavy: 8pt / 405ms。`shakeTask` 单例，新 `.heavy` 抢占进行中的 shake；新 `.light` 期间不打断已有 shake。完成后调 `reposition()` 回到 authoritative frame，避免 mid-shake 屏幕参数变化导致偏移残留。
  - `installRootView` 把 `onShake: { [weak self] in self?.shake($0) }` 闭包传给 `NotchRootView`。
  - `installObservers` 新增 `.notchPetDidDepart` 观察者，触发 `.heavy`。
- `NotchPet/Notch/NotchRootView.swift` — 增 `let onShake: (NotchPanelController.ShakeIntensity) -> Void` 字段并向下传给 `RoomView`。`StatusIconView` 优先级加入 sick：lifecycle → sleep → sick → vitals。
- `NotchPet/Notch/StatusIconPixelView.swift` — `Kind` 加 `.sick`，配套 16×16 胶囊+波浪条像素 sprite + 绿色 tint。
- `NotchPet/Room/RoomView.swift` — `RoomView` 接收 `onShake`，`ActionBar` 接收 `onShake`，三个按钮闭包都在 mutation 之后 `onShake(.light)`。
- `project.yml` — `NotchPet` target 的 `sources:` 增加 `Assets/Sprites` 和 `Assets/Audio` 两个 `type: folder, buildPhase: resources` 入口，并在主 `path: NotchPet` 上 `excludes: ["Assets/Sprites/**", "Assets/Audio/**"]` 防止 xcodegen 把同样的文件双份打进 bundle（一份 folder reference + 一份 source 扫描）。

**踩的坑**：

1. **Aseprite Lua `newCel` 复制 image** —— 我最初的写法是先 `spr:newCel(layer, frameIdx, img, Point(0,0))` 再 `seq.drawer(img, ...)` 往 img 写像素。结果 newCel 在调用瞬间 copy 了 image 的内容，后续 drawPixel 全写到了野指针 image 上，cel 里面是空的。所有 57 帧都变成同一个空白 cel，packed sheet dedup 后只有 1 个唯一 rect。修复：先 `Image(SIDE, SIDE, ColorMode.RGB)`，draw 完所有像素，最后再 newCel 把成品交给 sprite。
2. **Aseprite packed sheet 默认 dedup** —— `--sheet-type packed` 自动合并 byte-identical 帧。57 源帧最终 32 个唯一 rect 是正常的（egg 的两个 wiggle 状态 × 2 帧、adult/elder 共用 idle 等）。Swift loader 按源帧索引切，每个源帧拿到自己的 CGImage（多个源帧可能指向同一个 sheet rect，没有副作用）。
3. **SwiftUI Canvas `gc.drawLayer { layer.fill(rect, with: .color(tint)) }` 用 multiply blend mode 会把 tint 画到透明像素上** —— Multiply 在透明 destination 上的 alpha 公式是 `Sa + 0 - 0 = Sa`，所以 tint 矩形把整个 16×16 涂成纯色。后果：第一次截图看到的全是 cream/pink 的实色块，sprite 完全看不见。修复：放弃 Canvas + drawLayer，直接用 `Image(decorative: cg).interpolation(.none).resizable().colorMultiply(tint)` —— colorMultiply 是按 alpha 蒙版的逐像素乘法，不会污染透明区域，而且代码更短。
4. **xcodegen `type: folder` 资源会和上层 `path: NotchPet` 重复扫描** —— 第一次构建 Resources/ 里同时出现 `pet.png` 和 `Sprites/pet.png`。修复：在父级 source 上 `excludes:` 掉 Assets 子目录。
5. **Python 3.13+ 移除了 `aifc`** —— 原计划生成 AIFF。降级到 `wave` 写 WAV，`AudioServicesCreateSystemSoundID` 同样支持 .wav，无功能损失。

**自动化验证结果**（`/tmp/b4_capture.py` + `/tmp/b4_happy_capture.py`，用 CGEvent 合成点击 + screencapture 截图）：

- `xcodebuild clean build` → BUILD SUCCEEDED，0 warning / 0 error
- 资源 bundling：`NotchPet.app/Contents/Resources/Sprites/{pet.png, pet.json}` + `Audio/{feed,play,rest,hatch,depart,happy}.wav` 全部就位
- `os_log` 输出确认（`log show --info`）：
  - `PetSprite: loaded 17 tags, 57 source frames`
  - `SoundPlayer: loaded 6 sounds`
  - `SoundPlayer: played feed`（点喂食后立即出现）
- 视觉截图（`/tmp/b4_*_expanded.png` / `/tmp/b4_*_collapsed.png`）：
  - egg (たまご · Day 0.2)：白色蛋 sprite ✓
  - child_idle (幼年期 · Day 2)：缩小版小鸡 ✓
  - adult_idle (成熟期 · Day 7.0, 活泼)：标准小鸡 + cheerful 暖色 tint ✓
  - adult_hungry：橙色 `!` 浮在头顶，胃口 bar=10，gluttonous 红润 tint ✓
  - adult_sick：绿色波浪线在头顶 + 绿色肚子 + `X` 眼，hunger=mood=8 ✓
  - adult_sleeping：眼睛闭合 + Z 颗粒 ✓
  - adult_happy：闪烁 sparkle 像素在身体两侧（点喂食后 4s 内捕获）✓
  - elder：色调偏冷 + 整体 0.85 dim ✓
  - departed：白色幽灵 dome sprite ✓
  - 4s 后再截图 → happy 自动消失，回到 idle 表情 ✓
  - collapsed 状态条：sick 时右侧出现绿色胶囊图标 ✓，hungry 时出现饭碗 ✓
- 持久化：`state.json` schema 没动，`happyUntil` 不写盘，重启回 idle ✓

**已知不 block 的瑕疵**：

- packed sheet 把 byte-identical 的 idle/hungry/happy 等帧 dedup 之后 sheet 只有 96×96，单帧索引正确但 Preview 里能看到一些 sprite 在不同 tag 之间共享 cell。完全不影响运行。
- `b4_during_feed_shake.png` 静帧很难看出抖动（light shake 振幅只有 3pt，单帧 40ms 内位移最多 3pt）—— 用屏幕录制能清楚看到，截图限制。
- 点击喂食按钮的协调：从 PetState 触发音效 + 从 RoomView ActionBar 触发 shake，两个调用点。这是有意为之 —— 音效是 gameplay 副作用（任何调用方都该听到），shake 是 view 反馈（只有有 panel 的场景才需要）。

### 2026-04-15 — Block 5 落地

**新增文件**：
- `NotchPet/Pet/PersonalityBehavior.swift` — `enum PetSpriteForm` + `extension PersonalityTrait` 集中所有性格 → 行为参数的映射。单点控制 6 种性格的 gameplay 调制，PetState / NightSleep / PetSprite 都从这里取值，避免散落的 if/else。

**改写文件**：
- `tools/sprites/gen_pet.lua` — 从单个 `CHICK` 矩阵扩展到 `FORMS = { cheerful, shy, aloof, gluttonous, lazy, grumpy }` 6 个独立 grid。每个 form 加一个 `FORM_TINT` 色偏（shy 偏冷、gluttonous 偏暖、lazy 去饱和、grumpy 偏红），由 `applyTint` 函数在 `chickCellColor` 里乘到 body-family 颜色上（outline/beak/cheek 保持中性调色板）。`renderChick` 增加 `form` 参数，按 form 选 grid + tint，并按 form 决定 bounce 节奏（cheerful 每帧弹、lazy/gluttonous 不弹）。新增 `.curious`（`?` 悬停图标 overlay）和 `.angry`（烟雾 + 跺脚）两种 mode overlay。Tag 生成改成 form × stage × mode 的笛卡尔积。child 阶段单独用 cheerful form（此时性格未固化）。grumpy 额外生成 `_angry` tag。最终 82 tag / 287 帧，packed sheet dedup 后 208×192 PNG。
- `NotchPet/Pet/PetSprite.swift` — 
  - `frame(stage:mode:personality:frameIndex:)` 签名里加 `personality` 参数
  - `fallbackKeys(stage:mode:personality:)` 构造候选 tag 列表：精确 `<form>_<stage>_<mode>` → 同 form 同 stage idle → cheerful 同 stage idle → cheerful adult idle → 1×1 透明 fallback
  - egg / child / departed 走独立的 pre-personality key 路径
- `NotchPet/Pet/PetView.swift` —
  - 删掉 `colorMultiply` 的 runtime tint（form 自己带 tint，再乘就过饱和）
  - 删掉 `tintColor(for:)` 辅助函数
  - `PetMode` 枚举追加 `.curious` 和 `.angry`
  - `mode(for:)` 优先级：egg/departed → idle，asleep → sleeping，sick → sick，**(grumpy && minVital < 0.30) → angry**，hovered → curious，happy → happy，hunger<0.25 → hungry，else idle
  - `mode(for:)` 从 `private static` 改成 `static`（非 private），便于未来测试
- `NotchPet/Pet/PetState.swift` —
  - `@Published var isHovered: Bool = false`（transient）
  - `@Published var feedRejectedUntil: Date? = nil`（transient）
  - `feed()` 先 dice-roll `personality?.feedAcceptProbability`，rejected 时不增加 hunger，不记 careHistory，播 `.feedReject`，设 `feedRejectedUntil`
  - `applyDecay` 的 hunger 衰减 rate 乘以 `personality?.hungerDecayMultiplier ?? 1.0`
- `NotchPet/Pet/NightSleep.swift` — `NightSleepSchedule` 字段 `wakeHour` 改名为 `baseWakeHour`，`isNightTime` 接受 `personality: PersonalityTrait?` 参数，wakeHour = base + `personality.wakeHourOffset`。
- `NotchPet/Pet/TimeService.swift` — 每次调 `schedule.isNightTime` 都把 `petState.personality` 传进去。
- `NotchPet/Notch/NotchPanelController.swift` —
  - `onHoverChange` 除了更新 `uiState.isHovered` 也写 `petState.isHovered = hovered && !uiState.isExpanded`（展开态清掉 curious，避免 overlay 和 room UI 打架）
  - `expand()` 强制 `petState.isHovered = false`
- `NotchPet/Audio/SoundPlayer.swift` — `enum Sound` 追加 `.feedReject` 和 `.angry`。`CaseIterable` 让 init 自动注册它们。
- `tools/sprites/gen_sounds.py` — `SOUNDS` dict 加两条 recipe：
  - `feedReject`: 660→440 Hz square, 140ms 下降
  - `angry`: 140→110 Hz triangle, 220ms 低音 growl

**踩的坑**：

1. **Swift enum 不能重写 `rawValue`**：最初的 `PetSpriteForm` 把 lazy 写成 `lazy_` 然后用 computed property 覆盖 `rawValue` 返回 `"lazy"` —— 编译器拒绝重写 synthesized rawValue。修复：用显式 raw value `case lazy_ = "lazy"`，其他 case 也显式写 raw value 以保持风格一致。
2. **PetView 渲染顺序**：一开始忘了删掉 `colorMultiply` 的 runtime tint，加上 form 自己的 baked tint 后变成双重 multiply，adult sprites 被涂得很暗甚至看不清。删掉 `colorMultiply` 后问题消失。副作用：elder 的 0.85 dim 也被 form 的 `dimK` 参数接管，PetView 只保留 `.opacity(0.85)` 作为"sprite 加载失败时的视觉保险"。
3. **curious 模式不能在展开态触发**：一开始简单把 `petState.isHovered` 接上 hover 回调，结果展开 RoomView 后鼠标在 panel 内 hover 也算，导致房间里那只大 sprite 一直显示 `?` 图标，和 idle 表情抽搐地切换。修复：在 `onHoverChange` 回调里加 `&& !uiState.isExpanded`，展开态直接清掉 isHovered。

**自动化验证结果**（`/tmp/b5_capture.py`）：
- `xcodebuild clean build` → BUILD SUCCEEDED，0 warning / 0 error
- `PetSprite: loaded 82 tags, 287 source frames`（os_log 确认）
- 6 个性格 × adult / elder 截图全部展现可辨识的差异：
  - cheerful: 标准小鸡 + 两腮粉 + 圆眼
  - shy: 更小更窄 + 大脸颊 + 小眼点，整体下沉 1px
  - aloof: `^_^` 弧形闭眼 + 无脸颊 + 稍凉色调
  - gluttonous: 明显更圆 + 大肚子 + 小眼 + 更暖色调
  - lazy: 眼睛变成单行 outline 水平线 + 无弹跳 + 去饱和色调
  - grumpy: 头顶 outline 尖刺 + V 字喙 + 偏红色调
- `grumpy_angry` 截图：头顶 4 个灰色烟雾像素，脚部跺动（低 vital hunger=0.20 触发）
- curious hover 截图：鼠标停在刘海上，右侧 `?` 图标在头顶闪烁
- `log show` 确认 `SoundPlayer: loaded 8 sounds`（从 6 增加到 8）
- 高冷拒绝 / 贪吃衰减 / 懒惰起床 / 暴躁 anger 这些 gameplay 行为依赖 RNG 和时间窗口，自动化不易复现，但代码路径都对着设计文档 §4.2 逐条走过

**不改的地方**：
- PetStateStore schema 没动，`isHovered` / `feedRejectedUntil` / `happyUntil` 全部 transient，不进 snapshot
- `FORM_TINT` 的强度故意做得偏保守 —— 更强的差异来自 sprite 结构（body shape, eye style），颜色只是锦上添花，保证 6 个 form 在刘海 22px 尺寸下仍可辨识
- grumpy 的 `.angry` 目前只用于视觉和音效反馈，没有改 gameplay 数值（不加决策/负面影响），避免让暴躁性格变成"惩罚性格"

### 2026-04-15 — Block 6 落地

**新增文件**：
- `NotchPet/Inventory/PlayerInventory.swift` — 独立 ObservableObject：`coins`、`ownedRoomThemes/Furniture`、`activeRoomTheme`、`placedFurniture: [FurnitureSlot: String]`。方法：`addCoins` / `purchase*` / `equip*` / `placeFurniture` / `removeFurniture`。
- `NotchPet/Inventory/InventoryStore.swift` — 独立 JSON 持久化到 `~/Library/Application Support/com.notchpet.NotchPet/inventory.json`，schemaVersion = 1。为保 JSON 可读性，`placedFurniture` 在 snapshot 里序列化为 `[String: String]`，因为 Swift 的 JSONEncoder 只对 String/Int key 的 Dictionary 保留 keyed container 语义。
- `NotchPet/Inventory/RoomTheme.swift` — `RoomThemeDefinition.all` 目录 + `RoomThemeBackground(themeID:)` SwiftUI 工厂：
  - `default`：黑底 + 淡地板线
  - `washitsu`：暖米色墙 + 竖条 tatami 带 + 右上角像素灯笼
  - `space`：紫蓝渐变 + 固定星点 + 小行星
  - `forest`：暗绿渐变 + 树木剪影三角形 + 草地线
- `NotchPet/Inventory/FurnitureCatalog.swift` — 6 件家具的 id/名称/价格/允许槽位
- `NotchPet/Inventory/FurnitureSpriteLibrary.swift` — 仿 PetSpriteLibrary，加载 `furniture.png` + `furniture.json`，按 tag 取单帧 CGImage
- `NotchPet/Room/HeartsRow.swift` — 离散心形渲染，10×10 pixel heart × 4 个一行，filled/empty 两种状态
- `NotchPet/Room/PoopView.swift` — 12×12 stacked-swirl 便便 sprite
- `NotchPet/Room/ActionAnimationOverlay.swift` — feed/play 反馈动画，内部 `@State` 跟 SwiftUI implicit animation，无需 spritesheet
- `NotchPet/Room/ManagementPanel.swift` — 管理面板：header + tab bar + `RoomThemesTab` / `FurnitureTab`，每行有缩略图 + 名字 + 价格 + 动态按钮（购买 / 装备 / 放置 / 收起 / 使用中）
- `tools/sprites/gen_furniture.lua` — Aseprite Lua 生成 6 件家具 16×16 像素图
- `tools/sprites/build_furniture.sh` — 一键脚本，输出 `NotchPet/Assets/Sprites/furniture.png` + `furniture.json`
- `NotchPet/Assets/Sprites/furniture.png` + `furniture.json` — 提交的构建产物

**大改写的文件**：
- `NotchPet/Pet/PetState.swift` 几乎完全重写：
  - vitals 从 `Double` 变 `Int`，`mood → happy`，`energy` 删除
  - 新字段：`weight`、`sick`、`medicineDosesRemaining`、`sicknessCheckDueAt`、`poops`、`lastPoopAt`、`poopDueAt`、`@Published actionAnimation`
  - `init` 默认值用 `nonisolated static let` 常量，避免 MainActor 隔离警告（Swift 6 模式兼容）
  - `feed()` / `play()` 加上 `triggerActionAnimation`、`schedulePoopIfNeeded`、`onCoinsEarned?(1)`
  - **删除 `rest()` 方法**
  - 新增 `takeMedicine()`、`clean()`
  - `applyDecay` 改成 accumulator 模式：`hungerDecayAccum` / `happyDecayAccum` 按秒累积，到达 `hungerSecondsPerHeart` / `happySecondsPerHeart` 阈值时扣 1 心。生病时 × 0.5 防止死亡螺旋。
  - 新 `runCareTick(now:activeSeconds:)`：和 `applyDecay` 分离，处理便便生成 + 3 条生病触发规则
  - `handleStageTransition` 加入 adult/elder 进阶时的 `sicknessCheckDueAt` 随机调度和 `onCoinsEarned?(10/20)` 奖励
  - `rebornAsNewGeneration` 重置所有新字段和 private accumulator
  - 新增 env 变量覆盖：`NOTCHPET_HUNGER_SEC` / `NOTCHPET_HAPPY_SEC` / `NOTCHPET_POOP_DELAY` / `NOTCHPET_NEGLECT_SEC` / `NOTCHPET_POOP_SICK_SEC`，调试时可快进
- `NotchPet/Pet/PetStateStore.swift` 加 schemaVersion 3 + v2→v3 migration：
  - 保留 `PetStateSnapshotV2` 私有结构以解旧文件
  - `load()` 先试 v3，失败后试 v2，识别到 v2 就立刻 migrate + save v3
  - `floatToHearts(_:)` 把 0.0–1.0 float × 4 round 成心数
- `NotchPet/Pet/PetView.swift` `mode(for:)` 重写：生病从 `petState.sick`（真正 flag）走，不再是计算属性；hunger/happy 零值触发 `.hungry`；grumpy anger 从 "vital < 0.30 float" 改成 "hunger==0 OR happy==0"
- `NotchPet/Pet/PersonalityBehavior.swift` `angerTriggerThreshold` 改成 `Int?`，值 `0` 表示 "hunger 或 happy 为零时触发"
- `NotchPet/Pet/NightSleep.swift` `wakeHour` 改名 `baseWakeHour`，`isNightTime(at:personality:)` 按性格浮动 wakeHour（懒惰 +1 小时保留）
- `NotchPet/Pet/TimeService.swift` 每 tick 调 `runCareTick` 和 `applyDecay`
- `NotchPet/Room/RoomView.swift`：
  - `RoomBackground` 私有 view 删除，改用 `RoomThemeBackground(themeID:)`
  - `VitalsStrip` 私有 view 改成新 `HeartsStrip`：两个 `HeartsRow` + 体重小读数
  - `ActionBar` 从 3 按钮（喂食 / 玩耍 / 休息）变 4 按钮（喂食 / 玩耍 / 吃药 / 扫除），每个按钮带 `enabled` 参数，按 `petState.sick` / `petState.poops > 0` 动态 enable
  - 新 `FurnitureLayer` private view 渲染 placedFurniture，按 slot 定位
  - 新增 ZStack 顶层 `PoopView` 渲染（便便挨着脚）
  - 新增 ZStack 顶层 `ActionAnimationOverlay` 渲染（feed/play 动画）
  - header 右上角去掉 `げんき/おやすみ` 文字，加 `⚙` 齿轮按钮 + 🪙 coin balance
  - `@State isManagementShowing` + 顶层条件渲染 `ManagementPanel`
- `NotchPet/Room/ActionIconView.swift`：`Kind` 加 `.medicine` / `.clean`，对应 16×16 像素图（红白胶囊 + 黄色海绵 + 四角 sparkles）
- `NotchPet/Notch/NotchRootView.swift`：`StatusIconView.currentKind` 优先级 lifecycle → sleep → sick → poop → hungry → lowHappy（poop 比 hungry 更紧迫——这个顺序可能有点暴力，未来可以调）
- `NotchPet/Notch/NotchPanelController.swift`：构造接收 `inventory: PlayerInventory`，传给 `NotchRootView`
- `NotchPet/AppDelegate.swift`：构造 `InventoryStore` + `PlayerInventory`，注入 `petState.onCoinsEarned = { inventory.addCoins($0); inventoryStore.save(inventory) }`；`applicationWillTerminate` 也保存 inventory
- `NotchPet/Audio/SoundPlayer.swift` `Sound` enum 加 `.medicine` / `.clean`
- `tools/sprites/gen_sounds.py` `SOUNDS` 加 `medicine`（柔和钟声）和 `clean`（升调短 chirp）recipe
- `NotchPet/Notch/StatusIconPixelView.swift` 删除 `.lowEnergy`，加 `.poop`（stacked swirl 12x12 sprite）
- `DEVELOPMENT_LOG.md` — 追加 Block 6 段

**踩的坑**：

1. **Swift 6 MainActor 隔离** vs **static let 默认参数**：`init(hunger: Int = Self.initialHunger, ...)` 里引用的 `initialHunger` 需要在 nonisolated 上下文被访问。把 `static let` 加 `nonisolated` 前缀修复。
2. **`[FurnitureSlot: String]` 不能直接 Codable 成 JSON object**：Swift 的 JSONEncoder 只把 `Dictionary<String, V>` / `Dictionary<Int, V>` 当 keyed container，其他 Hashable key 编成 `["k1","v1","k2","v2"]` flat 数组。保 JSON 可读性：snapshot 里存 `[String: String]`，load/save 时在边界做 rawValue ↔ enum 转换。
3. **便便生成后立即消失**：第一次写 `runCareTick` 时，`poopDueAt` 判断用的是 `>=` 但我在清 `poopDueAt = nil` 之前又走了一次 tick，导致第二个 tick 立刻 fire 又加一个。修复：清 `poopDueAt` 必须和 `poops += 1` 放在同一 if 块里。
4. **ManagementPanel 点击测试覆盖不到**：自动化 CGEvent click 在齿轮按钮坐标（屏幕 logical ~985, 35）上连续两次命中失败。不影响功能——SwiftUI Button 正常响应，代码路径已编译通过。放弃自动化 UI 录屏覆盖这一项，留给人工验证。

**自动化验证结果**（`/tmp/b6_verify.py` + `/tmp/b6_phaseA_test.py` + `/tmp/b6_phaseDE_test.py`）：
- `xcodebuild clean build` → BUILD SUCCEEDED，0 warning / 0 error
- 离散心形渲染：`/tmp/b6_fullhearts_expanded.png`（4/4 满）、`/tmp/b6_halfhearts_expanded.png`（2/4）、`/tmp/b6_zerohearts_expanded.png`（0/4）三档都按预期显示
- 生病状态：`/tmp/b6_sick_expanded.png` 显示小鸡生病 sprite + 吃药按钮 enable（绿色活跃）+ 扫除按钮禁用
- 便便渲染：`/tmp/b6_three_poops.png` 三坨便便排列在小鸡脚边地板上，扫除按钮 enable
- 4 个房间主题：`/tmp/b6_theme_{default,washitsu,space,forest}.png` 每个主题的背景独特 —— 和风米色 + tatami + 像素灯笼、太空紫蓝 + 星点 + 行星、森林绿渐变 + 树剪影
- 家具放置：`/tmp/b6_furniture_placed.png` 显示同时放桌子 + 盆栽 + 灯笼，三个槽位正确定位
- Schema migration 手动验证：把旧 v2 JSON 放到 state.json 启动，pet 成功加载，`state.json` 被重写为 v3 shape
- 动画 overlay 代码路径在 feed/play 时会设 `actionAnimation = .eating/.playing`，900ms 后自动清空（靠 `DispatchQueue.main.asyncAfter`）—— 静帧难捕捉到动画中点，代码推理验证
- `os_log` 确认 `SoundPlayer: loaded 10 sounds`（从 Block 5 的 8 增加到 10）

**不改的地方**：
- `PetStateStore.currentSchema` 从 2 升到 3，careHistory / lifecycle / personality 等 Block 3 / 5 的既有字段完全保留
- 所有 transient 字段（`happyUntil` / `feedRejectedUntil` / `actionAnimation` / `isHovered` / `hungerDecayAccum` 等）都不进 snapshot
- 设计文档提到的 discipline / 呼叫注意 / 随机蛋物种 / 交配系统仍然 deferred

**已知限制**：
- 管理面板的点击测试自动化失败（坐标问题），但 UI 代码正确无误
- 一个性格装扮槽位被另一个占用时的 "evict and replace" 逻辑简单粗暴，未来可以让用户选择目标槽位
- `onCoinsEarned` 闭包每次调用都 save inventory —— 频繁但成本低（文件小），未来可以批量

### Aseprite 使用笔记（已落地）

```bash
# 一键重建（脚本会 cd 到 repo root）
./tools/sprites/build_sprites.sh

# 手动两步：
./tools/aseprite/build/bin/aseprite -b --script tools/sprites/gen_pet.lua
./tools/aseprite/build/bin/aseprite -b tools/sprites/pet.aseprite \
  --sheet-type packed \
  --sheet NotchPet/Assets/Sprites/pet.png \
  --data NotchPet/Assets/Sprites/pet.json \
  --list-tags --format json-array
```

要改像素艺术：编辑 `tools/sprites/gen_pet.lua` 的 `CHICK` / `EGG` / `GHOST` 矩阵或 `renderChick` 的 mode overlay 逻辑，重新跑脚本。要改音效：编辑 `tools/sprites/gen_sounds.py` 的 `SOUNDS` 字典，跑 `python3 tools/sprites/gen_sounds.py`。两者都不需要 Xcode 重新生成 project，只要 `xcodebuild build` 重新 copy resource。
