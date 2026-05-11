# anytls-manager

水饺自用 anytls-go 管理脚本。

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/shuijiao1/anytls-manager/main/anytls.sh)
```

自动从 anytls-go 最新 Release 下载对应架构：

- `x86_64/amd64` → 官方 `linux_amd64`
- `aarch64/arm64` → 官方 `linux_arm64`
- `armv7l` → 若官方 Release 没有预编译包，自动拉取最新 tag 源码并本机 Go 编译 server
