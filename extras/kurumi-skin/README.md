# 时崎狂三桌宠素材包

桌宠主体基于 [QCYTSN/dsh-dafeiyu](https://github.com/QCYTSN/dsh-dafeiyu)，原作者与贡献者拥有主体功能、设计和稳定版贡献。本素材包配合本分支的 macOS 自定义皮肤支持，增加狂三外观和五个姿态；不将原桌宠记作本次原创。

`images/` 包含待机、思考、翻书工作、开心招手和拖起反应五个姿态，以及与待机图对应的闭眼图 `idle-blink.png`。眨眼仅融合眼部局部，不整张切换闭眼图；脚底锚点、呼吸相位、头发/上半身轻摆、姿态过渡和拖放回弹保持连续。素材以用户选定的同一角色原型生成，随后仅作确定性缩放；角色为《约会大作战》的时崎狂三，这些是新生成的同人图，非官方素材，并非逐帧手绘动画或 Live2D 模型。

## 安装选择

需要先安装此分支重新构建的 macOS Helper；上游未包含自定义皮肤功能的旧二进制不会读取这份选择文件。先关闭 DSH，再构建/安装此分支插件；然后在仓库根目录运行：

```sh
node extras/kurumi-skin/install-skin.mjs --dry-run
node extras/kurumi-skin/install-skin.mjs
dsh web
```

安装器只复制本目录六张图片到 `$DSH_HOME/dsh-dafeiyu/skins/kurumi/` 并写入 `$DSH_HOME/dsh-dafeiyu/skin.json`（含 `blinkImagePath`）。默认 `DSH_HOME` 为 `~/.dsh`。已有皮肤选择会先保存为 `skin.json.backup-<timestamp>`；不修改其他插件、频道、模型或凭据，不结束进程。

删除或移走 `skin.json` 后重启，可恢复插件原始皮肤；安装器保留的旧选择备份可用于恢复此前的自定义皮肤。

## 检查

```sh
node --test extras/kurumi-skin/install-skin.test.mjs
```

检查仅在自动创建的临时目录中验证路径、备份与 dry-run，不触及真实 DSH 配置。桌宠代码许可证遵循仓库根目录 [LICENSE](../../LICENSE)；生成素材与角色权利说明见上文。
