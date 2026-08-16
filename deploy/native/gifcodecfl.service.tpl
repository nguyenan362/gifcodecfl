[Unit]
Description=Giftcode CFL native service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=__CFL_APP_USER__
WorkingDirectory=__CFL_INSTALL_ROOT__
EnvironmentFile=__CFL_ENV_FILE__
ExecStart=__CFL_INSTALL_ROOT__/server
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
