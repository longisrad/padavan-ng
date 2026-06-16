THISDIR = $(shell pwd)

# Đường dẫn đến file thực thi và cấu hình mẫu trong phân vùng build
BINARY_NAME = AdGuardHome
URL_DOWNLOAD = https://static.adguard.com/adguardhome/release/AdGuardHome_linux_mipsle_softfloat.tar.gz

all:
	@echo "AdGuard Home package ready."

clean:
	rm -rf install
	rm -rf AdGuardHome.tar.gz
	rm -rf AdGuardHome

romfs:
	# 1. Kiểm tra nếu chưa có file nén thì mới tải về để tránh lỗi mất mạng khi build liên tục
	if [ ! -f AdGuardHome.tar.gz ]; then \
		wget -O AdGuardHome.tar.gz $(URL_DOWNLOAD); \
	fi
	
	# 2. Giải nén và dọn dẹp cấu trúc thư mục tạm
	rm -rf install AdGuardHome
	tar -xzvf AdGuardHome.tar.gz
	mv AdGuardHome install
	
	# 3. TỐI ƯU DUNG LƯỢNG (Bắt buộc): Xóa debug symbols để giảm từ 35MB xuống còn ~10-15MB
	$(STRIP) install/$(BINARY_NAME)
	
	# 4. Phân phối file thực thi vào phân vùng hệ thống /usr/bin/ của ROM
	$(ROMFSINST) $(THISDIR)/install/$(BINARY_NAME) /usr/bin/$(BINARY_NAME)
	
	# 5. Phân phối file cấu hình mặc định .yaml vào /etc_ro/ để script .sh lấy làm mẫu
	$(ROMFSINST) $(THISDIR)/AdGuardHome.yaml /etc_ro/AdGuardHome.yaml
	
	# 6. Phân phối file script điều khiển adguardhome.sh và cấp quyền thực thi (+x)
	$(ROMFSINST) -p +x $(THISDIR)/adguardhome.sh /usr/bin/adguardhome.sh
