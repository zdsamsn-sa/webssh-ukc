#!/usr/bin/env bash
# 从源码编译 WebSSH 静态二进制并推送到 Unikraft Cloud 镜像仓库
# 用法: bash scripts/build-webssh.sh [实例名]
set -euo pipefail
cd "$(dirname "$0")/.."

NAME="${1:-webssh}"
TOKEN="${UNIKRAFT_API_TOKEN:?缺少 UNIKRAFT_API_TOKEN}"
ORG=$(printf '%s' "$TOKEN" | base64 -d | cut -d: -f1 | sed -e 's/^robot\$//' -e 's/\.users\.kraftcloud$//')
[ -n "$ORG" ] || { echo "无法从 token 解析组织名"; exit 1; }

APP_DIR="app"
[ -d "$APP_DIR" ] || { echo "缺少 $APP_DIR/（请放入 webssh 源码，含 main.go 与 public/）"; exit 1; }
[ -f "$APP_DIR/main.go" ] || { echo "缺少 $APP_DIR/main.go"; exit 1; }
[ -f "$APP_DIR/public/index.html" ] || { echo "缺少 $APP_DIR/public/（需已构建前端或使用仓库自带 public）"; exit 1; }

echo "===== 1/3 编译 Linux amd64 静态二进制 ====="
command -v go >/dev/null 2>&1 || { echo "需要 Go 工具链"; exit 1; }
(
  cd "$APP_DIR"
  # 与 upstream build.sh 一致：纯静态、无 cgo
  CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags "-s -w -extldflags -static" \
    -o webssh \
    .
  test -x webssh
  echo "二进制大小: $(wc -c < webssh) bytes"
)

echo "===== 2/3 组装 rootfs（alpine 最小层 + 二进制）====="
rm -rf _img
mkdir -p _img
# 拉 alpine 作为基础（有 /bin/sh 等）
python3 scripts/pull-base.py library/alpine 3.20 _img/rootfs || \
  python3 scripts/pull-base.py library/alpine 3.20 _img/rootfs https://mirror.gcr.io

mkdir -p _img/rootfs/webssh
cp -a "$APP_DIR/webssh" _img/rootfs/webssh/webssh
chmod 755 _img/rootfs/webssh/webssh

# 启动脚本：读 PORT / USER+PASS / authInfo，前台运行（禁止 tail -f 保活写法）
cat > _img/rootfs/start.sh << 'START'
#!/bin/sh
set -e
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
cd /webssh || cd /

PORT="${PORT:-8888}"

# 认证：优先 authInfo，其次 USER+PASS（与 upstream 环境变量一致）
if [ -n "${authInfo:-}" ]; then
  exec ./webssh -p "$PORT" -a "$authInfo"
fi
if [ -n "${USER:-}" ] && [ -n "${PASS:-}" ]; then
  exec ./webssh -p "$PORT" -a "${USER}:${PASS}"
fi
exec ./webssh -p "$PORT"
START
chmod 755 _img/rootfs/start.sh
echo "--- start.sh ---"
cat _img/rootfs/start.sh

cat > _img/Kraftfile <<KF
spec: v0.7
runtime: base-compat:latest
rootfs:
  source: ./rootfs
  format: erofs
cmd: ["/bin/sh", "/start.sh"]
KF

echo "===== 3/3 登录并推送 $ORG/$NAME:latest ====="
printf '%s' "$TOKEN" | unikraft login --token=- --organization "$ORG" >/dev/null
echo "已登录 org=$ORG"
unikraft build _img --output "$ORG/$NAME:latest"
echo "完成: $ORG/$NAME:latest"
echo "部署: PROJECT_NAME=$NAME APP_PORT=8888 REGIONS=sin bash scripts/deploy.sh deploy"
