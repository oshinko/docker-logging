# Docker Logrotate

Docker コンテナにおけるログ管理は、標準出力と標準エラーに出力し、それをホスト側で管理する方法が主流になっている。

ログローテーションを実現する際に、主に次のパターン (詳細は後述) が考えられる。

1. Docker コンテナ標準のロギング設定
2. ホスト側 Linux の logrotate を使う

## Docker 公式イメージの Nginx について

ここでは Docker 公式イメージの Nginx を利用しているが、このイメージはデフォルトで標準出力と標準エラーにログが出力されるようになっている。

これは、次のようなシンボリックリンクによるものである。

```txt
# ls -la /var/log/nginx
total 8
drwxr-xr-x    2 root     root          4096 Jan 1 00:00 .
drwxr-xr-x    1 root     root          4096 Jan 1 00:00 ..
lrwxrwxrwx    1 root     root             0 Jan 1 00:00 access.log -> /dev/stdout
lrwxrwxrwx    1 root     root             0 Jan 1 00:00 error.log -> /dev/stderr 
```

シンボリックリンクを使わずに次のような設定 (nginx.conf) でも実現できる。

```txt
server {
  ...
  access_log /dev/stdout main;
  error_log  /dev/stderr warn;
```

## [Docker コンテナ標準のロギング設定](https://docs.docker.com/config/containers/logging/configure/)

Docker のデフォルトのロギングドライバーである `json-file` の設定例。

Linux の場合。

```sh
sudo sh -c 'cat << EOF > /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "10"
  }
}
EOF'
sudo service docker restart
```

Windows や macOS の場合 "Windows Docker Desktop daemon.json"
などで検索し、編集方法を特定する。

### クラウドに書き込む

ログメッセージを Amazon CloudWatch Logs に書き込む場合の設定例。

```sh
{
  "log-driver": "awslogs",
  "log-opts": {
    "awslogs-region": "ap-northeast-1",
    "awslogs-group": "/tmp",
    "awslogs-create-group": true
  }
}
```

## ホスト側 Linux の logrotate を使う

「Docker コンテナ標準のロギング設定」におけるローテーションの振る舞いは、ログドライバに依存する。

例えば `json-file` ログドライバでは、時間や日付を基準としたローテーションが実現できない。

ここでは Linux でよく使われる logrotate を使ったローテーションを提案する。

```sh
if command -v apt > /dev/null 2>&1; then
  # On Debian, Ubuntu, and other apt based systems
  pm=apt
elif command yum > /dev/null 2>&1; then
  # On Fedora, Red Hat Enterprise Linux and other yum based systems
  pm=yum
else
  echo "Could not find package manager"
  exit 1
fi

$pm update
$pm install -y logrotate

cat << EOF > /etc/logrotate.d/docker
/var/lib/docker/containers/*/*.log {
  rotate 1
  hourly
  missingok
  copytruncate
  compress
  delaycompress
}
EOF
```
