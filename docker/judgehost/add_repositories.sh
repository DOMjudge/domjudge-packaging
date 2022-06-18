apt-get update
apt-get install software-properties-common gnupg

echo "deb [trusted=yes] https://pc2.ecs.baylor.edu/apt focal main" >> /etc/apt/sources.list
echo 'Acquire::https::pc2.ecs.baylor.edu::Verify-Peer "false";
Acquire::https::pc2.ecs.baylor.edu::Verify-Host "false";' >> /etc/apt/apt.conf.d/80trust-baylor-mirror

apt-get update
