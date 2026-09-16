# WebSSH → Unikraft Cloud 完整部署教程

将 [WebSSH](https://github.com/eooce/webssh)（浏览器里的 SSH 终端 + SFTP）部署到 [Unikraft Cloud](https://unikraft.cloud)。

| 组件 | 说明 |
|------|------|
| 应用 | Go 后端 + Vue 前端，官方镜像 `eooce/webssh` |
| 端口 | 容器内默认 **8888**，UKC 对外 **443 HTTPS** |
| 认证 | 可选 Web Basic 登录（`USER`/`PASS` 或 `authInfo`） |
| 触发 | GitHub Actions **手动** Run workflow |

---

## 目录

1. [原理与可用性](#1-原理与可用性)
2. [准备条件](#2-准备条件)
3. [首次部署](#3-首次部署)
4. [使用说明](#4-使用说明)
5. [自定义域名](#5-自定义域名)
6. [更新与删除](#6-更新与删除)
7. [目录结构](#7-目录结构)
8. [环境变量一览](#8-环境变量一览)
9. [故障排查](#9-故障排查)
10. [安全建议](#10-安全建议)
11. [限制说明](#11-限制说明)

---

## 1. 原理与可用性

### WebSSH 做什么

- 在浏览器打开页面，填写目标主机 IP/域名、端口、用户名、密码或密钥
- 通过 WebSocket 建立到 **目标机器** 的 SSH 会话
- 支持 SFTP 文件浏览、上传、下载
- 多标签、明暗主题、登录后初始命令等

### 为什么适合 Unikraft Cloud

- 单一进程监听 HTTP 端口（默认 8888）
- 不依赖 systemd / Docker-in-Docker
- 本方案在 CI 中 **从源码编译静态二进制**（避免官方 Docker 镜像 `start.sh & tail -f` 不适合 unikernel，以及未 login 就 build 的问题）

### 可用性结论

| 能力 | 状态 |
|------|------|
| Web 终端（密码 / 密钥） | ✅ |
| SFTP 文件管理 | ✅ |
| WebSocket 终端 | ✅（UKC `tls+http` 可升级） |
| Web 端登录保护 | ✅（配置 USER/PASS） |
| 出站 SSH 到你的服务器 | ✅（实例需能访问目标 22 端口） |
| 持久化保存会话密码 | ⚠️ 主要在浏览器侧；实例无状态卷也可正常用 |

> **重要**：WebSSH 是 **跳板/客户端**，不是在 UKC 里开系统 SSHD。  
> 你从浏览器连到 WebSSH 页面，再由 WebSSH **主动连出** 到你的 VPS/服务器。

---

## 2. 准备条件

### 2.1 账号

1. GitHub 账号  
2. Unikraft Cloud 账号 + **API Token**（控制台 Settings → API Keys）

### 2.2 推送本仓库

解压本包后：

```bash
cd webssh-ukc
git init
git add .
git commit -m "WebSSH on Unikraft Cloud"
git branch -M main
git remote add origin https://github.com/你的用户名/仓库名.git
git push -u origin main
```

建议仓库设为 **Private**。

### 2.3 Secrets（必填 / 强烈建议）

仓库 → **Settings → Secrets and variables → Actions**

| Name | 必填 | 说明 |
|------|------|------|
| `UNIKRAFT_API_TOKEN` | **是** | Unikraft API Token |
| `WEBSSH_USER` | 强烈建议 | Web 页面登录用户名 |
| `WEBSSH_PASS` | 强烈建议 | Web 页面登录密码 |

> 不设 `WEBSSH_USER`/`WEBSSH_PASS` 时，**任何人打开 URL 都能使用 WebSSH 去连任意主机**，风险极高。

### 2.4 可选 Variables

| 变量 | 默认 | 说明 |
|------|------|------|
| `PROJECT_NAME` | `webssh` | 实例/服务/镜像名 |
| `DEPLOY_REGIONS` | `sin` | `sin` / `fra` / `dal` / `sfo` / `was` |
| `MEMORY_MB` | `512` | 内存 MB |
| `APP_PORT` | `8888` | 容器内端口（一般不用改） |
| `SAVE_PASS` | `true` | 是否允许前端记住 SSH 密码 |

---

## 3. 首次部署

### 步骤 1：打开 Actions

GitHub 仓库 → **Actions** → **Deploy WebSSH to Unikraft Cloud** → **Run workflow**

### 步骤 2：填写参数（可全默认）

| 项 | 建议 |
|----|------|
| 项目名 | `webssh` |
| 地区 | 离你近的，如新加坡 `sin` |
| 内存 | `512` |
| （已改为源码构建，无需填镜像） | |

### 步骤 3：等待完成

约 2–6 分钟，流程：

```text
安装 unikraft CLI
→ 安装 Go，编译 linux/amd64 静态二进制
→ 基于 alpine 组装 rootfs + 正确前台启动脚本
→ unikraft login 后 build 推送到你的 org
→ 创建 service（443→8888）并启动实例
```

日志末尾示例：

```text
===== 部署完成 =====
sin  running  https://xxxxxxxx.sin.unikraft.app
```

### 步骤 4：验证

1. 浏览器打开该 HTTPS 地址  
2. 若配置了 `WEBSSH_USER`/`WEBSSH_PASS`，应弹出 Basic 认证  
3. 进入连接页，填一台你有权限的测试机，确认能出终端  

---

## 4. 使用说明

### 连接远程主机

1. 打开 WebSSH 页面  
2. 填写：
   - 主机：公网 IP 或域名  
   - 端口：一般 `22`  
   - 用户名：如 `root`  
   - 认证：密码 或 私钥  
3. 连接后进入终端；可开多标签  
4. 文件面板可做 SFTP 上传/下载  

### 一键快捷链接（若前端支持）

部分版本支持把连接参数编码进 URL，便于书签。以你部署的前端界面为准。

### 从 UKC 出站

UKC 实例需要能访问目标主机的 SSH 端口（通常 22）。  
若目标只允许白名单 IP，需在安全组放行 **UKC 出口 IP**（以实际环境为准，可能随平台变化）。

---

## 5. 自定义域名

### 方式 A：UKC 原生绑定

1. DNS CNAME：

```text
ssh.example.com  →  xxxxxxxx.sin.unikraft.app
```

Cloudflare 建议该记录先用 **灰云（仅 DNS）**。

2. CLI 绑定 Service（服务名一般是 `项目名-地区`，如 `webssh-sin`）：

```bash
unikraft services list
unikraft services edit webssh-sin \
  --domains xxxxxxxx.sin.unikraft.app \
  --domains ssh.example.com
```

只配 CNAME、不 `services edit`，会出现：

```text
There is no service on this URL.
```

### 方式 B：Cloudflare Worker 反代

```js
export default {
  async fetch(req) {
    const url = new URL(req.url);
    url.hostname = "xxxxxxxx.sin.unikraft.app";
    return fetch(new Request(url, req));
  },
};
```

WebSocket 一般可走通；注意 CF 代理下源站看到的是 CF IP。

---

## 6. 更新与删除

### 更新

- 换镜像 tag 或官方发了新版 → 再跑一次 **Deploy** workflow  
- **同名项目**会先删实例再创建（短暂中断）  

### 删除

Actions → **Destroy** → `target` 填 `webssh`（或你的项目名）或 `all`，再填 `DELETE` 确认。

---

## 7. 目录结构

```text
webssh-ukc/
├── .github/workflows/
│   ├── deploy.yml         # 源码构建并部署
│   └── destroy.yml
├── app/                   # WebSSH 源码（Go + 已构建 public/）
│   ├── main.go
│   ├── controller/ core/
│   └── public/
├── scripts/
│   ├── build-webssh.sh    # 编译静态二进制 + 推 UKC 镜像
│   ├── deploy.sh
│   ├── anyimage.sh        # 通用镜像导入（已修 login）
│   └── pull-base.py
└── README.md
```

### 部署链路

```text
go build（CGO_ENABLED=0, linux/amd64）
  → alpine rootfs + /webssh/webssh
  → start.sh 前台 exec（读 PORT / USER / PASS）
  → unikraft login + build → $ORG/webssh:latest
deploy.sh deploy
  → service: 443:8888/tls+http
  → 注入 PORT / USER / PASS / authInfo
  → unikraft run（常驻）
```

---

## 8. 环境变量一览

| 变量 | 来源 | 作用 |
|------|------|------|
| `PORT` | workflow 固定/变量 | 监听端口，默认 8888 |
| `USER` | Secret `WEBSSH_USER` | 镜像常用 Web 登录用户名 |
| `PASS` | Secret `WEBSSH_PASS` | 镜像常用 Web 登录密码 |
| `authInfo` | 由 USER:PASS 自动拼接 | 与源码 `-a user:pass` / 环境变量 `authInfo` 对齐 |
| `savePass` | Variable `SAVE_PASS` | 是否允许保存 SSH 密码 |

源码还支持命令行：

```text
-p 端口
-a user:pass
-t SSH超时(分钟)
-s 是否保存密码
```

镜像入口一般已用环境变量覆盖，无需改命令行。

---

## 9. 故障排查

| 现象 | 可能原因 | 处理 |
|------|----------|------|
| Actions 失败缺 token | 未配 Secret | 配置 `UNIKRAFT_API_TOKEN` |
| 拉镜像失败 | Docker Hub 限流/网络 | 本方案已改为源码构建，不再依赖该镜像 |
| `profile not setup` / 未 login | anyimage 在 build 前未 login | 已修复；请用新版包重新部署 |
| 实例秒退 / CPU 0 | Docker CMD 为 `start.sh & tail -f` | 已改为前台 `exec ./webssh` |
| `No image` | 镜像同步延迟 | 脚本已重试；再跑一次 Deploy |
| 打开域名无服务 | 未绑定自定义域 | 见第 5 节 `services edit` |
| 页面无 Basic 认证 | 未设 USER/PASS | 配置 Secrets 后重新部署 |
| 能打开页但 SSH 连不上 | 目标防火墙/密钥错误 | 本机先 `ssh user@host` 验证；检查 UKC 出站 |
| 终端空白 / WS 失败 | 反代未支持 WebSocket | 用官方 `*.unikraft.app` 测试；自建反代需 Upgrade |
| 注册表 403 | 镜像配额约 1GiB | 控制台删除无引用旧镜像 |

本地 CLI 排查：

```bash
export UNIKRAFT_API_TOKEN='...'
unikraft instances list
unikraft services list
unikraft instances logs webssh
```

---

## 10. 安全建议

1. **务必**设置 `WEBSSH_USER` / `WEBSSH_PASS`，不要把未认证的 WebSSH 暴露在公网。  
2. Web 密码与 SSH 密码使用不同强口令。  
3. 仓库建议 Private；Token 只放 Secrets。  
4. 仅用于管理自己的机器；不要当作对外公开的「任意 SSH 代理」。  
5. 自定义域名优先原生绑定；注意审计谁能打开该 URL。

---

## 11. 限制说明

1. UKC **不是**完整 VPS：实例内不能再跑 Docker、不能当跳板机装额外系统服务。  
2. WebSSH 进程负责 **出站 SSH**；入站只有 HTTP(S)。  
3. 无持久卷时，实例重建不保留容器内临时文件（连接信息主要在浏览器）。  
4. 多地区部署会起多个独立实例，不会自动同步。  

---

## 快速检查清单

- [ ] 已添加 `UNIKRAFT_API_TOKEN`
- [ ] 已添加 `WEBSSH_USER` / `WEBSSH_PASS`
- [ ] Deploy 成功并打开 `https://….unikraft.app`
- [ ] 弹出 Web 登录且能进入连接页
- [ ] 能 SSH 到至少一台测试主机并看到终端
- [ ] （可选）自定义域名已 CNAME + `services edit`

完成以上即表示部署可用。

---

## 许可

- 本仓库部署脚本：按说明使用。  
- WebSSH 应用：遵循上游 [eooce/webssh](https://github.com/eooce/webssh) 的 LICENSE。
