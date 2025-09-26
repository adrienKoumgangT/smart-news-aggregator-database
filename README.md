# Smart News Aggregator Configuration


## Global Strategy

I have this distribution roles to balance load:

- Machine 1:
  - MongoDB Primary
  - Redis Slave
  - Prometheus
- Machine 2:
  - MongoDB Secondary
  - Redis Master
  - Grafana
- Machine 3:
  - MongoDB Arbiter
  - Redis Sentinel
  - Tomcat Rest API
  - React Frontend

This way, the database are spread out, monitoring tools are split, and services (API/frontend) are isolated.


## MongoDB Setup (Replica Set: Primary, Secondary, Arbiter)

the script for install mongodb on all 3 machines :
```bash
sudo apt update
sudo apt install -y gnupg curl
curl -fsSL https://pgp.mongodb.com/server-7.0.asc | sudo gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg
echo "deb [ arch=amd64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
sudo apt update
sudo apt install -y mongodb-org
sudo systemctl enable mongod
sudo systemctl start mongod
```


edit /etc/mongod.conf
```yaml
replication:
  replSetName: "rs0"
net:
  bindIp: 0.0.0.0
```


restart:
```bash
sudo systemctl restart mongod
```

Initialize replicat set (on primary)
```bash
mongosh
```

```javascript
rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "10.1.1.17:27017", priority: 2 },
    { _id: 1, host: "10.1.1.18:27017", priority: 1 },
    { _id: 2, host: "10.1.1.19:27017", arbiterOnly: true }
  ]
})
```

```javascript
rs.status()
```


## Redis Setup (Master, Slave, Sentinel)

Install Redis on all 3 machines:
```bash
sudo apt update
sudo apt install -y redis-server
```

on machine 2 (Master) /etc/redis/redis.conf:
```ini
port 6379
bind 0.0.0.0
```

on machine 1 (Slave) /etc/redis/redis.conf:
```ini
replicaof 10.1.1.18 6379
```

on machine 3 (Sentinel) /etc/redis/sentinel.conf:
```ini
port 26379
bind 0.0.0.0
sentinel monitor mymaster 10.1.1.18 6379 2
sentinel down-after-milliseconds mymaster 5000
sentinel failover-timeout mymaster 10000
sentinel parallel-syncs mymaster 1
```


enable services:
```bash
sudo systemctl enable redis-server
sudo systemctl restart redis-server
```

sentinel:
```bash
redis-server /etc/redis/sentinel.conf --sentinel
```

check replication:
```bash
redis-cli -h 10.1.1.17 info replication
```


## Prometheus (Machine 1) + Grafana (machine 2)

### Prometheus

```bash
sudo useradd --no-create-home --shell /bin/false prometheus
wget https://github.com/prometheus/prometheus/releases/download/v2.55.0/prometheus-2.55.0.linux-amd64.tar.gz
tar -xvzf prometheus-2.55.0.linux-amd64.tar.gz
sudo mv prometheus-2.55.0.linux-amd64 /opt/prometheus
```

Config /opt/prometheus/prometheus.yml:
```yaml
scrape_configs:
  - job_name: "mongodb"
    static_configs:
      - targets: ["10.1.1.17:27017","10.1.1.18:27017"]

  - job_name: "redis"
    static_configs:
      - targets: ["10.1.1.17:6379","10.1.1.18:6379"]

  - job_name: "tomcat"
    static_configs:
      - targets: ["10.1.1.19:8080"]

  - job_name: "node"
    static_configs:
      - targets: ["10.1.1.17:9100","10.1.1.18:9100","10.1.1.19:9100"]
```

run:
```bash
/opt/prometheus/prometheus --config.file=/opt/prometheus/prometheus.yml
```

### Grafana

```bash
sudo apt install -y software-properties-common
sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
sudo apt update
sudo apt install -y grafana
sudo systemctl enable grafana-server
sudo systemctl start grafana-server
```

Access : http://10.1.1.18:3000
Default login:
- username: admin
- password: admin




