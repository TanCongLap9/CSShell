@{
  Intro = @"
Trình thông dịch C#
Nhập /help để cho ra danh sách các câu lệnh của trình thông dịch.
"@
  Help = @"
/print <cái gì đó>: Ghi ra giá trị hoặc kết quả trả về, kiểu giống như Console.WriteLine(<cái gì đó>).
/main [edit]: Chạy lệnh không cần hàm Main lun, ghê chưa?
  Thêm vào "edit" sau lệnh này để chỉnh sửa tập tin tạm thời trước khi chạy
/run [edit/<tập tin>]: Chạy code C# (tức là cần phải khai báo hàm Main và lớp chứa hàm).
  Thêm vào "edit" sau lệnh này để chỉnh sửa tập tin tạm thời trước khi chạy
/compile [edit/<tập tin>]: Biên dịch code thành EXE và chạy nó.
  Thêm vào "edit" sau lệnh này để chỉnh sửa tập tin tạm thời trước khi chạy
/exit HOẶC Ctrl+C: Thoát trình thông dịch.
"@
  FileNotFound = "Tập tin '{0}' không tồn tại."
  UnknownCommand = "Lệnh {0} là lệnh gì chứ?"
  ReferenceNotFullySupported = "Gán kết quả trả về từ hàm không được hỗ trợ đầy đủ.`nNên chạy lệnh trong /main hoặc /run để được hỗ trợ đầy đủ."
  Pause = "Nhấn nút Enter để chạy."
}