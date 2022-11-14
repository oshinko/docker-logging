# Docker Logging

Docker コンテナにおけるログ管理は、標準出力と標準エラーに出力し、それをホスト側で管理する方法が主流になっている。

ここで取り上げるログ管理には、主に次の観点がある。

1. ログの出力・保存先
1. ローカルファイルシステム上のログの世代管理 (ログローテーション)

ログの出力・保存先がローカルファイルシステムであれば、世代管理を考える必要がある。

Docker には、[標準のロギング設定](https://docs.docker.com/config/containers/logging/configure/)があり、標準出力と標準エラーに出力されたログの取り扱いを、ログドライバーというものに委譲する。

このログドライバーにより、出力先をローカルファイルシステム、あるいは Amazon CloudWatch Logs などのクラウドなどに変更できる。

## Docker コンテナ標準のロギング設定

Docker のデフォルトのロギングドライバーである `json-file` の設定例。

Linux の場合。

```sh
[ -f /etc/docker/daemon.json ] && \
  sudo mv /etc/docker/daemon.json /etc/docker/daemon.`date +%s`.json
sudo sh -c 'cat << EOF > /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "10"
  }
}
EOF'
sudo docker stop `sudo docker ps -q`
sudo docker rm `sudo docker ps -a -q`
sudo service docker restart
```

Windows や macOS の場合 "Windows Docker Desktop daemon.json"
などで検索し、編集方法を特定する。

### クラウドに書き込む

ログメッセージを Amazon CloudWatch Logs に書き込む場合の設定例。

```sh
[ -f /etc/docker/daemon.json ] && \
  sudo mv /etc/docker/daemon.json /etc/docker/daemon.`date +%s`.json
sudo sh -c 'cat << EOF > /etc/docker/daemon.json
{
  "log-driver": "awslogs",
  "log-opts": {
    "awslogs-region": "ap-northeast-1",
    "awslogs-group": "/tmp/docker-logging-testing",
    "awslogs-create-group": "true"
  }
}
EOF'
a=`sudo docker ps -aq` && [ "$a" != "" ] && sudo docker rm -f $a
sudo service docker restart
```

## ホスト側 Linux の logrotate を使う

「Docker コンテナ標準のロギング設定」におけるロギングの振る舞いは、ログドライバに依存する。

例えば、ローカルファイルシステム上にログを出力する `json-file` ログドライバでは、時間や日付を基準としたローテーションは実現できない。

クラウドにログを出力する類のドライバであれば、ローテーションは気にしなくて良いかもしれないが、ローカルファイルシステム上に出力する場合、無限に蓄積するわけにはいかない。

ここでは Linux でよく使われる logrotate を使った、より柔軟なローテーションの実現方法を提案する。

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

# Required directives: copytruncate
sudo sh -c 'cat << EOF > /etc/logrotate.d/docker
/var/lib/docker/containers/*/*.log {
  rotate 7
  daily
  copytruncate
  missingok
  compress
  delaycompress
}
EOF'
```

## 付録

### Docker 公式イメージの Nginx について

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
