#!/bin/sh

# Update, rebuild and install netdata
[ "$1" = update ] && { git -C netdada pull; ~/netdata/netdata-installer.sh; whiptail --msgbox "netdata updated!" 8 32; break; }
[ "$1" = remove ] && { sh sysutils/service.sh remove netdata; rm /etc/nginx/sites-*/netdata; systemctl restart nginx; sh sysutils/service.sh remove netdata; ~/netdata/netdata-uninstaller.sh --force; rm -r ~/netdata; whiptail --msgbox "netdata removed." 8 32; break; }

# Defining the port
port=$(whiptail --title "netdata port" --inputbox "Set a port number for netdata" 8 48 "19999" 3>&1 1>&2 2>&3)

install_choice=$(whiptail --title Seafile --menu "	What netdata packages installation do you want?" 16 96 3 \
"Basic" "System monitoring and many applications. No mariadb, named, hardware sensors and SNMP" \
"Advanced" "Install all the required packages for monitoring everything netdata can monitor" \
"DP basic" "Most basic installation. Don't include Python unlike previous choices" \
3>&1 1>&2 2>&3)


[ "$install_choice" = "Basic" ] && { curl -Ss 'https://raw.githubusercontent.com/firehol/netdata-demo-site/master/install-required-packages.sh' >/tmp/kickstart.sh && bash /tmp/kickstart.sh netdata; }
[ "$install_choice" = "Advanced" ] && { curl -Ss 'https://raw.githubusercontent.com/firehol/netdata-demo-site/master/install-required-packages.sh' >/tmp/kickstart.sh && bash /tmp/kickstart.sh netdata-all; }

# https://github.com/firehol/netdata/wiki/Installation
# ArchLinux
if [ "$install_choice" = "DP basic" ] && [ $PKG = pkg ] ;then
  $install netdata
elif [ "$install_choice" = "DP basic" ] ;then
  # Debian / Ubuntu
  [ $PKG = deb ] && $install zlib1g-dev uuid-dev libmnl-dev gcc make autoconf autogen automake pkg-config

  # Centos / Fedora / Redhat
  [ $PKG = rpm ] && $install zlib-devel libuuid-devel libmnl-devel gcc make autoconf autogen automake pkgconfig

  cd
  # download it - the directory 'netdata' will be created
  git clone https://github.com/firehol/netdata --depth=1

  # build it, install it, start it
  ~/netdata/netdata-installer.sh
fi

# Run netdata via Caddy's proxying
if hash caddy 2>/dev/null ;then
  [ $IP = $LOCALIP ] && access=$IP || access=0.0.0.0
  cat >> /etc/caddy/Caddyfile <<EOF
http://$access:$port {
    proxy / localhost:19999
}
EOF
  systemctl restart caddy

# Pass netdata via a nginx
else
  [ $IP = $LOCALIP ] && access=$IP: || access=
  $install nginx
  cat > /etc/nginx/sites-available/netdata <<EOF
upstream backend {
  # the netdata server
  server 127.0.0.1:19999;
  keepalive 64;
}

server {
  # nginx listens to this
  listen $access$port;

  # the virtual host name of this
  server_name \$hostname;

  #location / {
  #  proxy_set_header X-Forwarded-Host $host;
  #  proxy_set_header X-Forwarded-Server $host;
  #  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  #  proxy_pass http://backend;
  #  proxy_http_version 1.1;
  #  proxy_pass_request_headers on;
  #  proxy_set_header Connection "keep-alive";
  #  proxy_store off;
  #}
}
EOF
  # Symlink sites-enabled to sites-available
  ln -s /etc/nginx/sites-available/netdata /etc/nginx/sites-enabled/netdata

  # Delete the default nginx server block
  rm -f /etc/nginx/sites-enabled/default

  # Reload Nginx
  systemctl restart nginx
fi

# stop netdata
killall netdata

# copy netdata.service to systemd
cp system/netdata.service /etc/systemd/system/

# let systemd know there is a new service
systemctl daemon-reload

# enable netdata at boot
systemctl enable netdata

# start netdata
service netdata start

whiptail --msgbox "netdata installed!

Open http://$URL:$port in your browser" 10 64
