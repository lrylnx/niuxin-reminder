<p align="center"><img src="assets/AppIcon.png" width="128" alt="牛信提醒图标"></p>
<h1 align="center">牛信提醒 · Niuxin Reminder</h1>
<p align="center">千牛在后台，消息提醒依然看得见。</p>

独立的 macOS 菜单栏应用，补充千牛聊天窗口被遮挡时不显示的消息提醒。使用 Swift / AppKit 编写，无第三方依赖。**非阿里巴巴官方产品。**

![提醒卡片预览，使用虚构昵称与账号](assets/preview.png)

## 下载与使用

从 [Releases](https://github.com/lrylnx/niuxin-reminder/releases/latest) 下载已发布的版本。1.0.2 从源码构建后，更新包位于 `dist/NiuxinReminder-1.0.2-universal.zip`；解压并将 **牛信提醒.app** 放到固定位置 `/Applications/牛信提醒.app`。支持 Apple Silicon 与 Intel；最低系统版本 macOS 12。

1. 启动千牛并登录，再启动牛信提醒。
2. 在右上角菜单栏找到牛角消息气泡图标。通过“预览提醒样式”检查弹窗。
3. 新消息到达时显示客户昵称、接待账号和头像。点卡片打开千牛；点 × 收起。
4. 菜单栏可暂停、恢复或退出。启动时不会重放历史消息，不自动设置登录启动。

本机发行包采用登录钥匙串中固定的 `TutorialQuickSend Local Signing` 证书签名，**尚未使用 Apple Developer ID 签名及公证**。macOS 可能阻止首次打开；确认来源后，可在“系统设置 → 隐私与安全性”按系统提示允许打开。无需关闭系统安全保护。也可从源码构建。

## 功能

- 400 × 124 点紧凑圆角卡片，昵称与接待账号并排展示。
- 独立高层级窗口，切换应用后不隐藏，不抢键盘焦点。
- 按住蓝色标题栏可拖动，自动保存位置；后续消息与重启后保持位置，显示器变化时自动移回可见区域。卡片正文仍可单击打开千牛。
- 客户头像按客户 ID 关联，获取失败显示昵称首字。
- 消息 ID 去重、日志截断与轮转恢复、重复启动检测。
- 明确点击千牛原生提醒或聊天内容时，自动移除对应会话的牛信提醒；千牛自动进入会话、后台未读归零不会收起卡片。其他客户或其他接待账号的提醒保留，全部处理后卡片自动消失。
- 单色模板菜单栏图标，适配浅色/深色菜单栏。

## 工作原理与数据

每 0.5 秒读取当前用户千牛日志新增部分：

```
~/Library/Application Support/Aliworkbench/System/log/app.log
```

通过 `ChatService` 的新消息到达事件触发提醒，按消息 ID 关联客户昵称、接待账号；通过 `FetchProfilePortrait` 记录关联头像 URL。头像仅从日志中的 `https://img.alicdn.com/` 地址加载，无需千牛登录凭据。应用不修改千牛、不注入进程、不发送聊天消息、不上传聊天记录、不提供遥测。头像使用内存缓存。

## 已知边界

- 在 macOS 的千牛 **9.97.85** 上实测。不同版本的日志格式、日志开关可能影响功能。
- 消息正文暂不可用；接待账号不是已验证的店铺展示名称。
- 数量表示本工具启动/上次收起后尚未处理的消息事件，**不是千牛实时未读数**。卡片显示最新的待处理客户，多位客户不会展开成列表。
- 在千牛前台也会提醒；暂停期间的事件不会恢复补发，不同步千牛免打扰设置。
- 点击仅打开千牛。指定客户的 `aliim` 跳转在多账号下无法可靠选中接待账号，因此未启用。
- 新客户可能要等千牛获取过头像后才有可用地址。全屏、空间和多屏效果以实际环境为准。
- Universal 包包含 Intel 架构，但当前实测环境为 Apple Silicon。

## 从源码构建

需要 macOS 和 Xcode Command Line Tools / Xcode。

```bash
bash scripts/test.sh
bash scripts/test-appkit.sh # 本机图形会话中的实际弹窗测试
bash scripts/build.sh
open dist/牛信提醒.app
```

构建脚本生成原创图标、Universal 应用、固定证书签名、ZIP 发行包及 SHA-256 校验文件。没有额外包管理器依赖。必须存在 `TutorialQuickSend Local Signing`（SHA-1：`1DDCB3B175991894FC207A24F0B13D5C41F502B6`）；缺失时停止构建，不能退回临时签名。

Bundle ID 固定为 `io.github.lrylnx.niuxin-reminder`，安装路径固定为 `/Applications/牛信提醒.app`。`scripts/signing.sh` 固定指定要求；构建前检查既有身份，全部资源写入后最后签名，严格验证所有架构，并通过修改资源再签名的副本检查指定要求连续性。私钥只留在钥匙串，不导出。CI 仅检查源码，不生成临时签名发行包。

1.0.1 将旧版临时签名一次性迁移为固定签名。若曾授予系统隐私权限，迁移可能需要重新授权一次；本工具通过日志同步关闭提醒，不新增辅助功能、输入监控或屏幕录制权限。签名连续性已由构建检查验证，实际系统权限保留仍以系统行为为准。

```bash
# 生成不含真实客户信息的样式预览
dist/牛信提醒.app/Contents/MacOS/Reminder --preview assets/preview.png
```

## 许可

[MIT](LICENSE)。图标为本项目原创，生成源文件位于 `scripts/IconGenerator.swift`。
