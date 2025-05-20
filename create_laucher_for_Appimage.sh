#!/bin/bash

# Colors for terminal output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if zenity is installed
if ! command -v zenity &> /dev/null; then
    echo -e "${YELLOW}Zenity không được cài đặt. Đang cài đặt...${NC}"
    sudo apt-get update && sudo apt-get install -y zenity || {
        echo -e "${RED}Không thể cài đặt zenity. Tiếp tục với giao diện dòng lệnh.${NC}"
    }
fi

# Check if running with sudo
check_sudo() {
    if [ "$EUID" -ne 0 ]; then
        if command -v zenity &> /dev/null; then
            zenity --error --title="Lỗi quyền" --text="Script này cần quyền sudo để chạy.\nVui lòng chạy lại với sudo." --width=300
        else
            echo -e "${RED}Script này cần quyền sudo để chạy. Vui lòng chạy lại với sudo.${NC}"
        fi
        exit 1
    fi
}

# Function to show a loader animation
show_loader() {
    echo -ne "${BLUE}$1${NC}"
    for i in {1..3}; do
        echo -ne "${YELLOW}.${NC}"
        sleep 0.3
    done
    echo -e " ${GREEN}Hoàn thành!${NC}"
}

# Function to get AppImage file using GUI or CLI
get_appimage() {
    if command -v zenity &> /dev/null; then
        APPIMAGE=$(zenity --file-selection --title="Chọn file AppImage" --file-filter="AppImage files (*.AppImage) | *.AppImage" 2>/dev/null)
        if [ -z "$APPIMAGE" ]; then
            zenity --error --title="Lỗi" --text="Không có file AppImage nào được chọn." --width=300
            exit 1
        fi
    else
        if [ -z "$1" ]; then
            echo -e "${RED}Lỗi: Không có AppImage được cung cấp. Cách dùng: $0 <AppImage> [Icon]${NC}"
            exit 1
        fi
        APPIMAGE=$1
    fi

    # Validate AppImage
    if [[ ! "$APPIMAGE" =~ \.AppImage$ ]]; then
        if command -v zenity &> /dev/null; then
            zenity --error --title="Lỗi" --text="File phải có phần mở rộng .AppImage." --width=300
        else
            echo -e "${RED}Lỗi: File phải có phần mở rộng .AppImage.${NC}"
        fi
        exit 1
    fi

    # Check if AppImage exists
    if [ ! -f "$APPIMAGE" ]; then
        if command -v zenity &> /dev/null; then
            zenity --error --title="Lỗi" --text="File AppImage không tồn tại: $APPIMAGE" --width=300
        else
            echo -e "${RED}Lỗi: File AppImage không tồn tại: $APPIMAGE${NC}"
        fi
        exit 1
    fi
}

# Function to get icon file using GUI or CLI
get_icon() {
    if command -v zenity &> /dev/null; then
        ICON_PROMPT=$(zenity --question --title="Icon" --text="Bạn có muốn thêm icon cho ứng dụng không?" --width=300 2>/dev/null)
        if [ $? -eq 0 ]; then
            ICON=$(zenity --file-selection --title="Chọn file icon" --file-filter="Image files | *.png *.jpg *.jpeg *.svg *.ico" 2>/dev/null)
            if [ -z "$ICON" ]; then
                zenity --info --title="Thông báo" --text="Không có icon nào được chọn. Tiếp tục mà không có icon." --width=300
            fi
        fi
    else
        ICON=${2:-}
    fi

    # Validate icon if provided
    if [ -n "$ICON" ] && [ ! -f "$ICON" ]; then
        if command -v zenity &> /dev/null; then
            zenity --error --title="Lỗi" --text="File icon không tồn tại: $ICON" --width=300
        else
            echo -e "${RED}Lỗi: File icon không tồn tại: $ICON${NC}"
        fi
        exit 1
    fi
}

# Function to get application name
get_app_name() {
    DEFAULT_NAME=$(basename "$APPIMAGE" .AppImage)
    
    if command -v zenity &> /dev/null; then
        CUSTOM_NAME=$(zenity --entry --title="Tên ứng dụng" --text="Nhập tên cho ứng dụng:" --entry-text="$DEFAULT_NAME" --width=300 2>/dev/null)
        if [ -n "$CUSTOM_NAME" ]; then
            APPNAME="$CUSTOM_NAME"
        else
            APPNAME="$DEFAULT_NAME"
        fi
    else
        APPNAME="$DEFAULT_NAME"
    fi
}

# Function to ask for desktop shortcut
create_desktop_shortcut() {
    CREATE_SHORTCUT=false
    
    if command -v zenity &> /dev/null; then
        zenity --question --title="Shortcut" --text="Bạn có muốn tạo shortcut trên Desktop không?" --width=300 2>/dev/null
        if [ $? -eq 0 ]; then
            CREATE_SHORTCUT=true
        fi
    fi
}

# Main function
main() {
    check_sudo
    
    # Get AppImage and icon
    get_appimage "$1"
    get_icon "$2"
    get_app_name
    create_desktop_shortcut
    
    # Determine the correct home directory
    if [ -n "$SUDO_USER" ]; then
        USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    else
        USER_HOME=$HOME
    fi

    DESKTOP_PATH="$USER_HOME/.local/share/applications"
    DESKTOP_FILE="$DESKTOP_PATH/$APPNAME.desktop"
    APPIMAGE_DEST="/opt/$APPNAME.AppImage"
    
    if [ -n "$ICON" ]; then
        ICON_DEST="/opt/$(basename "$ICON")"
    fi

    # Create applications directory if it doesn't exist
    mkdir -p "$DESKTOP_PATH"

    # Make AppImage executable
    chmod +x "$APPIMAGE"
    show_loader "Đang cấp quyền thực thi cho AppImage"

    # Move AppImage to /opt
    cp "$APPIMAGE" "$APPIMAGE_DEST"
    show_loader "Đang sao chép AppImage vào /opt"

    # Move icon to /opt if provided
    if [ -n "$ICON" ]; then
        cp "$ICON" "$ICON_DEST"
        show_loader "Đang sao chép icon vào /opt"
    fi

    # Create the .desktop file
    mkdir -p "$DESKTOP_PATH"
    cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=$APPNAME
Comment=Application launcher for $APPNAME
Exec=$APPIMAGE_DEST
Terminal=false
Type=Application
Categories=Utility
$( [ -n "$ICON" ] && echo "Icon=$ICON_DEST" || echo "" )
EOF
    show_loader "Đang tạo file .desktop"

    # Create desktop shortcut if requested
    if [ "$CREATE_SHORTCUT" = true ]; then
        cp "$DESKTOP_FILE" "$USER_HOME/Desktop/"
        chmod +x "$USER_HOME/Desktop/$(basename "$DESKTOP_FILE")"
        chown $SUDO_USER:$SUDO_USER "$USER_HOME/Desktop/$(basename "$DESKTOP_FILE")"
        show_loader "Đang tạo shortcut trên Desktop"
    fi

    # Update desktop database
    update-desktop-database "$DESKTOP_PATH" &>/dev/null
    show_loader "Đang cập nhật cơ sở dữ liệu desktop"

    # Final message
    if command -v zenity &> /dev/null; then
        zenity --info --title="Hoàn thành" --text="Ứng dụng đã được thêm vào menu thành công!\n\nChi tiết:\n- AppImage: $APPIMAGE_DEST\n- Icon: ${ICON:+$ICON_DEST}\n- Desktop File: $DESKTOP_FILE\n\nBạn có thể tìm thấy \"$APPNAME\" trong menu ứng dụng của bạn! 🎉" --width=400
    else
        cat <<EOF

${GREEN}Hoàn thành! Ứng dụng đã được thêm vào menu thành công.${NC}
Chi tiết: 
  AppImage: $APPIMAGE_DEST
  Icon: ${ICON:+$ICON_DEST (hoặc không được đặt)}
  Desktop File: $DESKTOP_FILE

Bạn có thể tìm thấy "$APPNAME" trong menu ứng dụng của bạn! 🎉
EOF
    fi
}

# Run the main function
main "$@"