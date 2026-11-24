#!/bin/sh
# 把本地仓库推到 GitHub
#
# 用法一（PAT，自动建仓）：
#   ./push-to-github.sh <GitHub用户名> <仓库名> <PAT>
#   PAT 需 repo 权限（classic 勾 repo；fine-grained 选 Repositories: Read and write）
#
# 用法二（SSH，仓库需已存在或先手动建）：
#   ./push-to-github.sh <GitHub用户名> <仓库名>
#
# 可选环境变量：
#   VISIBILITY=private|public   （默认 public）
#   PROXY=socks5h://192.168.1.10:1070  （走旁路由代理时设置）

set -e
USER_NAME="${1:?用法: $0 <用户名> <仓库名> [PAT]}"
REPO_NAME="${2:?用法: $0 <用户名> <仓库名> [PAT]}"
TOKEN="${3:-}"
VISIBILITY="${VISIBILITY:-public}"
PROXY="${PROXY:-}"

cd "$(dirname "$0")"

apply_proxy() {
    [ -n "$PROXY" ] || return 0
    export ALL_PROXY="$PROXY"
    export https_proxy="$PROXY"
    export http_proxy="$PROXY"
    git config --local http.proxy "$PROXY"
    echo "· 使用代理 $PROXY"
}

apply_proxy

if [ -n "$TOKEN" ]; then
    echo "· 创建仓库 $USER_NAME/$REPO_NAME（$VISIBILITY）"
    CODE=$(curl -s -o /tmp/gh_create.json -w '%{http_code}' \
        -X POST https://api.github.com/user/repos \
        -H "Authorization: Bearer $TOKEN" \
        -H "Accept: application/vnd.github+json" \
        -d "{\"name\":\"$REPO_NAME\",\"private\":$([ "$VISIBILITY" = private ] && echo true || echo false),\"description\":\"LuCI card-style UI for Tailscale (Lua LuCI)\"}")
    case "$CODE" in
        201) echo "· 仓库已创建" ;;
        422) echo "· 仓库已存在，继续推送" ;;
        *) echo "· 创建失败 HTTP $CODE"; head -c 400 /tmp/gh_create.json; echo; exit 1 ;;
    esac
    git remote remove origin 2>/dev/null || true
    git remote add origin "https://$USER_NAME:$TOKEN@github.com/$USER_NAME/$REPO_NAME.git"
    git push -u origin HEAD:main
    git remote set-url origin "https://github.com/$USER_NAME/$REPO_NAME.git"
else
    git remote remove origin 2>/dev/null || true
    git remote add origin "git@github.com:$USER_NAME/$REPO_NAME.git"
    echo "· 用 SSH 推送（需已把公钥加到 GitHub，且仓库已存在）"
    GIT_SSH_COMMAND="ssh -F /vol1/@appshare/Harness/.ssh/config -o StrictHostKeyChecking=no" \
        git push -u origin HEAD:main
fi

echo
echo "· 完成：https://github.com/$USER_NAME/$REPO_NAME"
