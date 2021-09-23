#!/usr/bin/env python3

import yaml

security_path = "/opt/domjudge/domserver/webapp/config/packages/security.yaml"

if __name__ == "__main__":
  with open(security_path, mode="rt") as f:
    security = yaml.load(f, Loader=yaml.FullLoader)
  security["security"]["firewalls"]["main"]["remote_user"] = {"provider": "domjudge_db_provider"}
  with open(security_path, mode="wt") as f:
    yaml.dump(security, f)
