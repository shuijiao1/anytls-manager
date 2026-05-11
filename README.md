# anytls-manager

水饺自用 anytls-go 管理脚本。

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/shuijiao1/anytls-manager/main/anytls.sh)
```

自动从 anytls-go 最新 Release 下载对应架构。当前官方 Release 有 `x86_64/amd64` 和 `aarch64/arm64` 预编译包；脚本包含 `armv7l` 识别逻辑，但如果官方没有发布 armv7 资产，会明确报错而不是误装。
