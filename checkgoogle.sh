#!/bin/bash
#此脚本功能为对当前的节点以及指定的passwall节点测速，若当前节点存在联通问题，则自动切换为可用节点。意在弥补passwall缺乏的自动切换节点的功能。
#在openwrt配合crontab定期运行既可。

# 定义检测URL和节点列表
CHECK_URL="http://www.gstatic.com/generate_204"
NODES=("EGrYxDTS" "lLhtZb9q" "MHoXeznl" "XmPpVHhj") # 替换为实际节点ID
CURRENT_NODE=$(uci get passwall.@global[0].tcp_node)
SWITCHED=false

# 记录当前节点和检测URL
logger -t "passwall-check" "Current node: $CURRENT_NODE"
logger -t "passwall-check" "Checking URL: $CHECK_URL"

# 定义一个函数来检查Google可用性
check_google() {
    response=$(curl -s -o /dev/null -w "%{http_code} %{time_total}" $CHECK_URL)
    status_code=$(echo $response | awk '{print $1}')
    time_total=$(echo $response | awk '{print $2}')

    logger -t "passwall-check" "HTTP status code: $status_code, Time taken: ${time_total}s"
    [ "$status_code" -eq 204 ]
}

# 初次检查Google可用性
if ! check_google; then
  logger -t "passwall-check" "Google is not accessible. Switching node..."

  for NODE in "${NODES[@]}"; do
    if [ "$NODE" != "$CURRENT_NODE" ]; then
      logger -t "passwall-check" "Switching to node: $NODE"
      uci set passwall.@global[0].tcp_node=$NODE
      uci commit passwall
      /etc/init.d/passwall restart
      SWITCHED=true

      # 等待几秒钟以确保节点切换完成
      sleep 10

      # 再次检查Google可用性
      if check_google; then
        logger -t "passwall-check" "Switched node to $NODE and Google is accessible."
        break
      else
        logger -t "passwall-check" "Switched node to $NODE but Google is still not accessible."
      fi
    fi
  done
else
  logger -t "passwall-check" "Google is accessible."
fi

if ! $SWITCHED; then
  logger -t "passwall-check" "Google is accessible or no alternative nodes available."
fi
