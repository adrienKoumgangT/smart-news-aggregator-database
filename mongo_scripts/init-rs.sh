#!/bin/bash
set -e

echo ">> Waiting for MongoDB to start..."
sleep 5

mongosh --quiet <<EOF
try {
  // Initiate if not already
  if (rs.status().ok !== 1) {
    print(">> Initiating replica set...");
    rs.initiate({
      _id: "rs0",
      members: [
        { _id: 0, host: "mongodb-primary:27017", priority: 2 },
        { _id: 1, host: "mongodb-secondary:27017", priority: 1 },
        { _id: 2, host: "mongodb-arbiter:27017", arbiterOnly: true }
      ]
    });
  } else {
    print(">> Replica set already initiated, reconfiguring hosts...");
    cfg = rs.conf();
    cfg.members[0].host = "mongodb-primary:27017";
    cfg.members[1].host = "mongodb-secondary:27017";
    cfg.members[2].host = "mongodb-arbiter:27017";
    rs.reconfig(cfg, { force: true });
  }
} catch (e) {
  print(">> Error in init script:");
  print(e);
}
EOF