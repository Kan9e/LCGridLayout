# LCGridLayout 验收说明（尚未执行真机测试）

源码和构建成功均不代表插件已在设备上验证。当前状态详见 README.md。

## 构建与签名

1. 完整 Xcode 安装在 `/Applications/Xcode.app`，iPhoneOS SDK 可用。
2. 运行 `bash scripts/build.sh`。日志写入 `logs/build.log`。
3. 仅编译、签名验证、Mach-O 平台/架构/依赖校验全通过后，脚本才复制产物到 `dist/LCGridLayout.dylib`。
4. 默认临时签名（ad hoc）仅证明 Mach-O 签名结构完整，不保证非越狱设备允许加载。需用当前 LiveContainer 的证书通过其模块签名功能重签。脚本也接受 `LCGRID_SIGN_IDENTITY`。
5. 不注入、重签、修改或重新打包原始 LiveContainer IPA。

## 安装与首要验证

1. LiveContainer → Tweaks 标签 → 全局文件夹根目录 → “Import Tweak” 导入 `dist/LCGridLayout.dylib`；不要放进某个应用专用子文件夹，宿主注入只读全局文件夹。
2. 点 Tweaks 页的签名按钮（需要已导入 JIT-Less 证书），确认无签名错误。
3. 设置页底部连续点击版本文字 5 次 → 出现 Developer Settings → 打开 “Load Tweaks to LiveContainer Itself”（本地化文本不同）。
4. 注意 LiveContainer 3.8.0 的上游逻辑：全局 Tweaks 条目数 ≤ 1 且没有应用专用文件夹时会直接跳过加载。目录里至少保留两个条目（例如同时保留 `LCFloatingMenu_FasterPop_2x_arm64.dylib`），否则插件不会被 dlopen。
5. 完全退出并重新打开 LiveContainer。读取设备沙盒 `Library/Logs/LCGridLayout.log` 或系统 Console 日志。
6. 必须同时看到 `Host gate passed: LiveContainer <版本> (>= 3.8.0); LCGridLayout_vN.dylib loaded` 和 `Mounted on native app-list hosting controller`，且主界面确实出现网格。只出现前者不算 UI 测试通过。日志里的版本号用来确认设备上运行的是哪一版 LiveContainer；`Mounted ... (safe.top=… navBottom=…)` 用于核对顶部间距。
7. 若 6 秒后仍无网格，日志会自动附带一份 `view hierarchy`（只含类名和标题，无应用名、bundle id、容器路径）。把它连同 iOS 版本一起回传；不得通过对任意窗口强行覆盖来假装成功。

## 功能和兼容性

- 切换 4/5 列、横竖屏、窄屏、iPad、多窗口；图标不重叠、不越过安全区。
- 覆盖层必须铺满宿主视图：标签栏毛玻璃下方不得透出原生列表的行或图标。
- 在 App 标签与其他标签之间来回切换，不得先闪原生列表再变网格；返回时应瞬间保持网格。
- 顶部工具条紧贴导航栏，不得有明显空白；工具条、搜索框、第一行图标之间的间距一致。导航栏大标题收起后，工具条应自动上移重新贴合。
- 顶部只有「恢复原生」（带回退图标）和「网格设置」两项；不得再出现「背景」按钮，网格设置图标保持原样。
- 冷启动（后台划掉再打开）：网格应在大约 0.15 秒内出现，图标随后补全；不得出现约 1 秒仍停在原生页面的情况。
- 自定义背景：选图后立即生效；切标签、冷启动后仍在；移除后恢复默认底色；取消选择不改变现有背景；深色和浅色下图标与名称仍可读。
- 相册选择器不请求相册权限（PHPicker），关闭后网格状态不受影响。
- 显示/隐藏名称，冷启动设置保留；VoiceOver 可读应用名称。
- 普通应用、加锁应用、需要签名/JIT 的应用、多任务应用均走原有启动行为。加锁应用在网格里应显示锁标。URL accepted 仅表示 URL 被接收，不能证明来宾成功启动。
- 缺少 URL scheme 或系统拒绝 openURL 时，必须出现“无法启动”提示，不允许静默无反应。
- 隐藏应用无图标、名称或占位泄露；隐藏标志在两种 plist 中出现均过滤。完整的隐藏应用认证通过原生列表处理。
- 本地/共享目录、损坏 plist、相同文件夹名称冲突：不提供可能启动错误应用的图标，回原生列表处理。
- 安装/卸载/隐藏后切回网格或下拉刷新；搜索输入和清除正确。当前网格按名称排序，不复用原列表自定义排序。
- 点击“原生列表 / 管理”后，原有安装、管理、容器选择、隐藏/删除和解锁操作可用；“返回网格”可恢复。
- 模块/设置/来源标签、原生推入页面、弹窗、系统文件选择器均不被网格覆盖。
- LCFloatingMenu 双指长按、悬浮菜单、多任务操作，分别在宿主和来宾中核验；对比仅开启 LCFloatingMenu 时的表现。
- 全局模块注入来宾时，LCGridLayout 宿主检查应退出，不建立网格或定时器。
- 重启、前后台、重复切换标签至少 20 次，不出现重复覆盖层、崩溃或无法点击原控件。

## 回退

1. 临时：网格内点“原生列表 / 管理”，或设置里的“恢复原生列表”，覆盖层隐藏、原列表照常可用。
2. 停止加载：关闭 Settings → Developer Settings 的 “Load Tweaks to LiveContainer Itself”，重启 LiveContainer。
3. 想留文件但停用：把 dylib 改名为 `*.disabled`（上游 TweakLoader 会跳过），或在 Tweaks 页删除它并重启。
4. 彻底删除：Tweaks 页删除文件 + 重启；NSUserDefaults 里残留的三个 `LCGridLayout.*` 键无副作用，日志 `Library/Logs/LCGridLayout.log` 可一并删除。无需修改 IPA。

## 实测记录模板

记录：iOS/设备型号、LiveContainer 版本及 IPA SHA-256、插件 SHA-256、证书方式、主进程 PID、宿主日志、网格截图、各条验收结果与崩溃日志。未执行项写“未测试”，不要写“通过”。
