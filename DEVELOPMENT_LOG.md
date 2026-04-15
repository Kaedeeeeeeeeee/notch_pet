# Notch Pet — 开发日志

> 与 `notch-pet-product-design.md` 配套使用。设计文档描述"做什么"，本文档记录"已经做了什么 / 下一步做什么"。

## 当前状态

**Block 1 代码完成，等待用户手动验收** + Aseprite CLI 后台编译中

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
- [ ] 手动：ESC / chevron 收起（用户本地验证）
- [ ] 手动：跨 Space / 全屏切换 / 休眠唤醒后窗口仍在（用户本地验证）
- [ ] 手动：外接屏为主屏时，宠物在 MBP 内建屏的刘海上（目前的使用场景就是这个，已自动验证）

**5. Aseprite CLI（为 Block 2 铺路）** ✅
- [x] clone aseprite 源码到 `tools/aseprite/`
- [x] `brew install ninja`
- [x] Skia m124 预编译包已自动下载到 `.deps/skia-m124`（由 `build.sh` 处理）
- [x] `build.sh --auto --norun` 编译完成（1562 目标，约 3 分钟）
- [x] 验证：`tools/aseprite/build/bin/aseprite --version` → `Aseprite 1.x-dev`

### Block 2 — 状态与时间（未开工）

- [ ] `PetState` 完整模型：饱腹度 / 心情 / 体力 + 衰减
- [ ] `TimeService`：绑定电脑活跃时间（`NSWorkspace` 休眠/唤醒/锁屏）
- [ ] 夜间睡眠时段（21:00~22:00 起，可配置）
- [ ] `RoomView` 补真实状态条 + 喂食/玩耍/休息按钮
- [ ] 状态 → 刘海态动画反馈（饿/开心/病）
- [ ] 持久化（`UserDefaults` 或 JSON）

### Block 3 — 生命周期 & 性格（未开工）

- [ ] `LifecycleService`：10 天阶段机（幼年/成熟/育儿/告别）
- [ ] 性格向量：幼年期可塑 → 成熟期固化
- [ ] 性格影响动画选择 / 行为参数
- [ ] 进化分支（基础树）
- [ ] 未婚离开 → 随机蛋 → 新世代循环

### Block 4 — 反馈与正式素材（未开工）

- [ ] 用 Aseprite CLI 导出正式 spritesheet
- [ ] 替换占位 PetRenderer，引入 `PetSprite` spritesheet loader
- [ ] idle/hungry/happy/sick 动画分支
- [ ] 8-bit 音效（AudioToolbox）
- [ ] 窗口抖动（`CGAffineTransform`）

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

### Aseprite 使用笔记（build 成功后补充命令）

规划的批量导出命令（Block 2 执行）：
```bash
./tools/aseprite/build/bin/aseprite -b input.aseprite --save-as "out_{frame}.png"
# 或 spritesheet：
./tools/aseprite/build/bin/aseprite -b input.aseprite --sheet sheet.png --data sheet.json
```
