
/run/haproxy:
  file.directory:
    - name: /run/haproxy
    - user: root
    - group: root
    - mode: 755

install:
  cmd.run:
    - name: yum install keepalived -y; yum install haproxy -y;

config_haproxy:
  file.managed:
    - name: /etc/haproxy/haproxy.cfg 
    - source: salt://k8s/templates/haproxy/haproxy.cfg
    - user: root
    - group: root
    - mode: 755



config_keepalived:
  file.managed:
    - name: /etc/keepalived/keepalived.conf
    - source: salt://k8s/templates/haproxy/keepalived.cfg
    - user: root
    - group: root
    - mode: 755
