[Unit]
Description=Giftcode CFL Cloudflare Tunnel
After=network-online.target __CFL_SERVICE_NAME__.service
Wants=network-online.target

[Service]
Type=simple
ExecStart=__CLOUDFLARED_BIN__ tunnel --config __CFL_CLOUDFLARED_CONFIG__ run
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
