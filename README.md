# Water Reminder

App nhỏ trên menu bar macOS nhắc uống nước định kỳ. Viết bằng Swift + AppKit, một file, không cần Xcode project.

- Đếm ngược trên menu bar, 30 giây cuối đếm từng giây
- Khoảng nhắc 15 / 20 / 30 / 45 / 60 phút hoặc tự nhập (1–240 phút)
- Tự sửa câu nhắc qua menu **Sửa câu nhắc…** (mỗi dòng một câu, lưu ở `~/Library/Application Support/WaterReminder/messages.txt`)
- Thông báo hệ thống, hoặc toast hiện ở màn hình đang có con trỏ chuột (bấm vào toast = đã uống)
- Uống rồi, Tạm dừng, Mở cùng macOS

## Yêu cầu

- macOS 14 trở lên
- Xcode Command Line Tools: `xcode-select --install`

## Build

```sh
./build.sh
```

Script build app vào `~/Applications/WaterReminder.app` rồi mở app. Lần đầu macOS sẽ hỏi quyền gửi thông báo.

Icon được vẽ bằng code trong `icon.swift`, sửa file này rồi chạy lại `./build.sh` để vẽ lại.
