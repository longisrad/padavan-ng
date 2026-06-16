#!/bin/sh

# Lấy các biến từ NVRAM
agh_enabled=$(nvram_get agh_enabled)
adguard_port=$(nvram_get adguard_port)
adguard_replace_dns=$(nvram_get adguard_replace_dns)

STORAGE_DIR="/etc/storage/AdGuardHome"
CONFIG_FILE="$STORAGE_DIR/AdGuardHome.yaml"
RAM_DIR="/tmp/AdGuardHome"
PID_FILE="/var/run/AdGuardHome.pid"

# Tự động tìm thư mục cấu hình phụ của dnsmasq trên Padavan
if [ -d "/tmp/dnsmasq.d" ]; then
    DNSMASQ_CONF_DIR="/tmp/dnsmasq.d"
else
    DNSMASQ_CONF_DIR="/etc/storage/dnsmasq/dnsmasq.d"
fi
DNSMASQ_AGH_CONF="$DNSMASQ_CONF_DIR/adguardhome.conf"

start_agh() {
    # 1. Kiểm tra nếu chưa có thư mục lưu cấu hình trên Flash thì tạo mới
    if [ ! -d "$STORAGE_DIR" ]; then
        mkdir -p "$STORAGE_DIR"
    fi

    # 2. Nếu chưa có file cấu hình .yaml, copy file mẫu từ rom ra
    if [ ! -f "$CONFIG_FILE" ]; then
        if [ -f "/etc_ro/AdGuardHome.yaml" ]; then
            cp /etc_ro/AdGuardHome.yaml "$CONFIG_FILE"
        else
            logger -t "AdGuardHome" "LỖI: Không tìm thấy file cấu hình mẫu tại /etc_ro/AdGuardHome.yaml!"
        fi
    fi

    # 3. Tạo thư mục làm việc tạm thời trên RAM để chứa bộ lọc (Filters) Tránh hại Flash
    if [ ! -d "$RAM_DIR" ]; then
        mkdir -p "$RAM_DIR"
    fi

    # 4. Xử lý điều phối DNS nhường sân cho AdGuard Home chặn quảng cáo
    if [ "$adguard_replace_dns" = "1" ]; then
        logger -t "AdGuardHome" "Đang cấu hình dnsmasq chuyển tiếp truy vấn sang AdGuard Home (Port 5353)..."
        
        # Đảm bảo thư mục dnsmasq phụ tồn tại
        mkdir -p "$DNSMASQ_CONF_DIR"
        
        # Tạo file cấu hình phụ bắt dnsmasq không lấy DNS nhà mạng và forward hết sang AGH
        echo "no-resolv" > "$DNSMASQ_AGH_CONF"
        echo "server=127.0.0.1#5353" >> "$DNSMASQ_AGH_CONF"
        
        # Khởi động lại dịch vụ DHCP/DNS của router để áp dụng
        restart_dhcpd
    fi

    # 5. Khởi động tiến trình chạy ngầm
    if [ -f "/usr/bin/AdGuardHome" ]; then
        logger -t "AdGuardHome" "Đang khởi động AdGuard Home trên cổng WebUI $adguard_port..."
        /usr/bin/AdGuardHome -c "$CONFIG_FILE" -w "$RAM_DIR" --no-check-update > /dev/null 2>&1 &
        
        # Đợi một chút để tiến trình sinh ra PID rồi ghi lại
        sleep 1
        pidof AdGuardHome > "$PID_FILE"
    else
        logger -t "AdGuardHome" "LỖI: Không tìm thấy file thực thi tại /usr/bin/AdGuardHome!"
    fi
}

stop_agh() {
    logger -t "AdGuardHome" "Đang dừng AdGuard Home và khôi phục DNS mặc định..."
    
    # 1. Kill tiến trình bằng PID file hoặc tên ứng dụng
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        kill -9 $PID 2>/dev/null
        rm -f "$PID_FILE"
    else
        killall -9 AdGuardHome 2>/dev/null
    fi
    
    # 2. Xóa cấu hình điều hướng trong dnsmasq nếu có để khôi phục DNS gốc
    if [ -f "$DNSMASQ_AGH_CONF" ]; then
        rm -f "$DNSMASQ_AGH_CONF"
        restart_dhcpd
    fi
    
    # 3. Xóa thư mục tạm trên RAM cho sạch bộ nhớ
    rm -rf "$RAM_DIR"
}

case "$1" in
    start)
        if [ "$agh_enabled" = "1" ]; then
            # Kiểm tra xem AGH đã chạy chưa để tránh chạy trùng tiến trình
            if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
                logger -t "AdGuardHome" "AdGuard Home đã đang chạy rồi."
            else
                start_agh
            fi
        fi
        ;;
    stop)
        stop_agh
        ;;
    restart)
        stop_agh
        sleep 1
        if [ "$agh_enabled" = "1" ]; then
            start_agh
        fi
        ;;
    *)
        echo "Sử dụng: $0 {start|stop|restart}"
        exit 1
        ;;
esac

exit 0
