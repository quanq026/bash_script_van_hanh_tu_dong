#!/bin/bash
set -e

ACTION=$1

if [ "$ACTION" == "clean" ]; then
    echo "=========================================="
    echo "🧹 Dọn dẹp tài nguyên hệ thống..."
    echo "=========================================="
    docker compose down
    echo "Hệ thống đã được dừng và dọn dẹp an toàn."
    exit 0
elif [ "$ACTION" == "run" ]; then
    echo "=========================================="
    echo "🚀 Khởi chạy hệ thống QuickBite Microservices..."
    echo "=========================================="
    docker compose up -d --build

    echo "🔍 Kiểm tra trạng thái PostgreSQL (tối đa 5 lần)..."
    MAX_RETRIES=5
    RETRY_COUNT=0
    DB_READY=false

    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo "Lần thử $RETRY_COUNT/$MAX_RETRIES: Kiểm tra pg_isready..."
        if docker exec quickbite-db pg_isready -U postgres > /dev/null 2>&1; then
            echo "✅ PostgreSQL đã sẵn sàng tiếp nhận kết nối."
            DB_READY=true
            break
        fi
        sleep 2
    done

    if [ "$DB_READY" = false ]; then
        echo -e "\033[0;31m[LỖI] Database không phản hồi sau 10 giây. Đang tắt hệ thống...\033[0m"
        docker compose down
        exit 1
    fi

    echo "⏳ Chờ 5 giây để Spring Boot khởi động..."
    sleep 5

    echo "🔍 Kiểm tra cổng API Gateway..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/v1/users/actuator/health || true)

    if [ "$HTTP_CODE" == "200" ]; then
        echo -e "\033[0;32mCỔNG GATEWAY HOẠT ĐỘNG ỔN ĐỊNH. HỆ THỐNG LIÊN THÔNG THÀNH CÔNG!\033[0m"
        exit 0
    else
        echo -e "\033[0;31m[LỖI] API Gateway trả về mã HTTP $HTTP_CODE. Xuất 30 dòng log cuối của container:\033[0m"
        docker compose logs --tail=30
        echo "Đang dọn dẹp hệ thống..."
        docker compose down
        exit 1
    fi
else
    echo "Sử dụng cú pháp: $0 [run | clean]"
    exit 1
fi
