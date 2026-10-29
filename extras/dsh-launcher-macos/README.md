# DSH 独立启动器（macOS Apple Silicon）

1.0.1：加入狂三应用图标。图标直接使用本仓库 `extras/kurumi-skin/images/idle.png` 已获认可的生成角色素材，以原比例打包为多分辨率 ICNS；未重新绘制角色。构建时自动生成，桌面和 Dock 共用。

本次新增：独立 Dock 图标、原生窗口、自动运行已安装的 `dsh web --no-open`、内嵌 WebKit 窗口、编辑快捷键、文件选择、关闭重开窗口，以及退出时结束自己启动的 DSH 进程。DSH 界面和插件沿用本机 web profile。此启动器是本地适配，非官方桌面客户端。

双击桌面的 `DSH 启动器.app`。关窗口后可点 Dock 图标恢复；`Command+Q` 退出启动器及它启动的 DSH / 桌宠。首次使用前应结束原终端的 DSH，避免占用 3080 端口。窗口无需浏览器标签页，外部登录授权链接仍交系统浏览器处理。

构建：`bash build.sh '/private/tmp/DSH 启动器.app'`。需已安装 DSH、Node 和 Apple Command Line Tools。启动器仅绑定本机回环地址，不把进程认证 URL 写入日志或源码。不包含模型、账号或对话数据。

本机验证：Apple Silicon 编译与 ad-hoc 签名检查通过；桌面 App 成功启动 DSH 并在独立窗口加载原界面；输入、粘贴和清空草稿已验证；未发送测试消息或改动模型配置。此源码不包含预编译分发包，也没有发布 npm 版本。

来源：DeepSeek Harness CLI 与界面归 DeepSeek 原作者；本仓库桌宠主体基于 [QCYTSN/dsh-dafeiyu](https://github.com/QCYTSN/dsh-dafeiyu)，狂三启动主题基于 [KylinQ01/dsh-startup-animation](https://github.com/KylinQ01/dsh-startup-animation)。新增启动器使用 Apple 系统 AppKit / WebKit，独立编写，未复制第三方启动器实现。
