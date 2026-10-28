# 狂三启动主题与聊天背景

基于 [KylinQ01/dsh-startup-animation](https://github.com/KylinQ01/dsh-startup-animation) 的外观适配。启动序列、壁纸、图片管理和设置页的主体实现归原作者 KylinQ01，MIT 许可证和提交来源见 [FORK.md](FORK.md) 与 [LICENSE](LICENSE)。本目录仅维护狂三的黑红金配色、时钟刻度环、默认图片/文案和 DSH 0.2 配置兼容。

片头采用角色立绘、时钟环、光点与淡入淡出；不是预渲染动画视频。默认图片为此次生成的《约会大作战》时崎狂三同人图，不作为官方素材或上游原创素材。

## 本地安装

先完全退出 DSH Web Host。在本目录运行：

```sh
pnpm pack
dsh plugin --profile web add ./dsh-startup-animation-2.1.0.tgz
dsh web
```

随后在 DSH 的「插件 → dsh-startup-animation」配置卡中预览、重播、换图和修改问候语。片头可点击或按键跳过；同标签短时间刷新不会重复播放。

用户图片与配置保存在 `$DSH_HOME/dsh-startup-animation/`，未设置 `DSH_HOME` 时使用 `~/.dsh/dsh-startup-animation/`。已有自定义头像、背景或文案会优先于本目录默认值。可在设置里恢复对应图片/文案的默认值，使用本衍生版提供的狂三素材。

## 检查

```sh
node check.mjs
```

检查使用临时 `DSH_HOME` 验证路由、配置、图片上传/恢复和启动页，不会读写实际账户配置；会在本目录生成可删除的 `preview/`。
