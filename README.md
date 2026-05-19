# AnyTLS-Manager

![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25?style=flat-square&logo=gnu-bash&logoColor=white)
![Version](https://img.shields.io/badge/version-v0.1.2-blue?style=flat-square)

**中文** | [English](README.en.md)

**AnyTLS-Go 管理脚本。**

> 面向 Debian / Ubuntu root 环境，优先使用自己的短链一键运行。

---

## 🎯 核心特性

- 安装 / 更新 AnyTLS-Go
- 交互式配置端口和密码
- systemd 服务管理
- 脚本自更新检查

---

## 🚀 快速开始

```bash
bash <(curl -Ls https://anytls.shuijiao.de)
```

备用方式：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/shuijiao1/AnyTLS-Manager/main/anytls.sh)
```

---

## ⚙️ 版本与发布

- 当前版本：`v0.1.2`
- 更新记录见 [`CHANGELOG.md`](CHANGELOG.md)
- GitHub Release 会根据 `CHANGELOG.md` 自动生成说明
- 维护者发布新版本可使用：

```bash
./release.sh <version> "更新说明"
```

---

## ⚠️ 注意事项

- 请在可信 VPS 上以 root 执行。
- 涉及防火墙、SSH、重装、转发规则等操作前，建议保留一个现有 SSH 会话不断开。
- 脚本默认只维护公开通用配置，不内置私人密钥或私人密码。
