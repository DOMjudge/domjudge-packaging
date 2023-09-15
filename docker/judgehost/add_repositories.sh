apt-get update
apt-get install software-properties-common gnupg

echo "deb [trusted=yes] https://sysopspackages.icpc.global/apt/jammy jammy main" >> /etc/apt/sources.list
echo 'Acquire::https::sysopspackages.icpc.global::Verify-Peer "false";
Acquire::https::sysopspackages.icpc.global::Verify-Host "false";' >> /etc/apt/apt.conf.d/80trust-baylor-mirror

apt-get update
