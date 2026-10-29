import tkinter as tk
from tkinter import ttk, scrolledtext, messagebox
import serial
import serial.tools.list_ports
import threading
import time

# --- [프로토콜 규격 상수] ---
UART_FRAME_SOF = 0xAA
UART_TYPE_DATA = 0x01
UART_TYPE_CMD  = 0x02
UART_TYPE_ACK  = 0x03
UART_TYPE_ERR  = 0x04

# --- [UART 프레임 파서 클래스 (명세서 6.2)] ---
class UartFrameParser:
    def __init__(self):
        self._reset()

    def _reset(self):
        self._state = 'WAIT_SOF'
        self._type = 0
        self._length = 0
        self._payload = bytearray()

    def feed(self, byte: int):
        if self._state == 'WAIT_SOF':
            if byte == UART_FRAME_SOF:
                self._state = 'WAIT_TYPE'
        elif self._state == 'WAIT_TYPE':
            self._type = byte
            self._state = 'WAIT_LENGTH'
        elif self._state == 'WAIT_LENGTH':
            if byte > 28:
                self._reset()
            else:
                self._length = byte
                self._payload = bytearray()
                self._state = 'WAIT_CRC' if byte == 0 else 'WAIT_PAYLOAD'
        elif self._state == 'WAIT_PAYLOAD':
            self._payload.append(byte)
            if len(self._payload) >= self._length:
                self._state = 'WAIT_CRC'
        elif self._state == 'WAIT_CRC':
            expected = self._type ^ self._length
            for b in self._payload:
                expected ^= b
            expected &= 0xFF

            frame = None
            if byte == expected:
                frame = {
                    'type': self._type,
                    'length': self._length,
                    'payload': bytes(self._payload),
                }
            self._reset()
            return frame
        return None

# --- [메인 GUI 애플리케이션] ---
class UartRepeaterApp:
    def __init__(self, root):
        self.root = root
        self.root.title("CORE-5300 FPGA / ATmega128 Smart Security UART Repeater")
        self.root.geometry("640x660")

        self.serial_port = None
        self.is_connected = False
        self.parser = UartFrameParser()

        # 알람 상태 관련 (상시 감시 모드 기본 활성화)
        self.is_alarm_active = False
        self.first_sensed_dist = None  # 침입 발생 시 처음 감지한 거리 (cm)
        self.mode_guard = True         # 상시 감시 모드 (모드 전환 스위치 제거 반영)
        self.last_distance = None      # 최근 수신된 Distance 값
        self.last_threshold = None     # 최근 수신된 Threshold 값
        self.stop_pending = False
        self.stop_timeout_id = None
        self.received_frames = 0
        self.received_bytes = 0
        self.distance_text = tk.StringVar(master=root, value="Distance: ----")
        self.threshold_text = tk.StringVar(master=root, value="Threshold: ----")
        self.link_text = tk.StringVar(master=root, value="통신: 연결 전")
        self.stop_text = tk.StringVar(master=root, value="STOP: 대기")

        self.create_widgets()
        self.refresh_ports()

    def create_widgets(self):
        # 상단 설정 프레임
        setup_frame = tk.LabelFrame(self.root, text="통신 설정", padx=10, pady=5)
        setup_frame.pack(fill="x", padx=10, pady=5)

        tk.Label(setup_frame, text="COM 포트:").pack(side="left")
        self.cb_ports = ttk.Combobox(setup_frame, width=15)
        self.cb_ports.pack(side="left", padx=5)

        tk.Button(setup_frame, text="새로고침", command=self.refresh_ports).pack(side="left", padx=5)

        self.btn_connect = tk.Button(setup_frame, text="연결", width=10, command=self.toggle_connection, bg="#4CAF50", fg="white")
        self.btn_connect.pack(side="left", padx=10)

        tk.Button(setup_frame, text="상태 요청", command=self.request_status).pack(side="left", padx=5)

        sensor_frame = tk.LabelFrame(self.root, text="센서 상태", padx=10, pady=5)
        sensor_frame.pack(fill="x", padx=10, pady=5)
        tk.Label(sensor_frame, textvariable=self.distance_text, anchor="w").pack(fill="x")
        tk.Label(sensor_frame, textvariable=self.threshold_text, anchor="w").pack(fill="x")
        tk.Label(sensor_frame, textvariable=self.link_text, anchor="w").pack(fill="x")
        tk.Label(sensor_frame, textvariable=self.stop_text, anchor="w").pack(fill="x")

        # 알람 제어 프레임 (STOP / ALARM)
        alarm_frame = tk.LabelFrame(self.root, text="알람 제어", padx=10, pady=10)
        alarm_frame.pack(fill="x", padx=10, pady=5)

        self.btn_stop = tk.Button(
            alarm_frame, text="STOP", width=12, height=2,
            command=self.send_stop, bg="#FF9800", fg="white",
            font=("Arial", 11, "bold")
        )
        self.btn_stop.pack(side="left", padx=10)

        self.btn_alarm = tk.Button(
            alarm_frame, text="ALARM", width=12, height=2,
            state="disabled", bg="#FF0000", fg="white",
            disabledforeground="white",
            font=("Arial", 11, "bold")
        )
        # 평소에는 보이지 않다가 알람 발생 시에만 pack()으로 표시한다.

        # 중앙 로그 창
        log_frame = tk.LabelFrame(self.root, text="통신 로그", padx=10, pady=5)
        log_frame.pack(fill="both", expand=True, padx=10, pady=5)

        self.txt_log = scrolledtext.ScrolledText(log_frame, wrap=tk.WORD, height=15)
        self.txt_log.pack(fill="both", expand=True)

        # 하단 수동 송신 프레임
        send_frame = tk.LabelFrame(self.root, text="명령(CMD) 수동 송신", padx=10, pady=10)
        send_frame.pack(fill="x", padx=10, pady=5)

        tk.Label(send_frame, text="입력 (예: stop) :").pack(side="left")
        self.ent_cmd = tk.Entry(send_frame, width=30)
        self.ent_cmd.pack(side="left", padx=5)
        self.ent_cmd.bind("<Return>", lambda event: self.send_cmd())  # 엔터키 전송 지원

        tk.Button(send_frame, text="전송", width=10, command=self.send_cmd, bg="#2196F3", fg="white").pack(side="left", padx=5)

    def log(self, msg, color="black"):
        timestamp = time.strftime("[%H:%M:%S]")
        tag_name = f"color_{color}"
        self.txt_log.tag_config(tag_name, foreground=color)
        self.txt_log.insert(tk.END, f"{timestamp} {msg}\n", tag_name)
        self.txt_log.see(tk.END)

    def refresh_ports(self):
        selected = self.cb_ports.get()
        ports = list(serial.tools.list_ports.comports())
        self.cb_ports['values'] = [port.device for port in ports]
        if self.cb_ports['values']:
            if selected in self.cb_ports['values']:
                idx = list(self.cb_ports['values']).index(selected)
            else:
                # Exact known board port takes precedence over another USB device.
                idx = min(range(len(ports)), key=lambda i: (
                    ports[i].device != "COM9",
                    "0403:6010" not in getattr(ports[i], 'hwid', ''),
                    "USB" not in ports[i].description.upper(), i))
            self.cb_ports.current(idx)

    def toggle_connection(self):
        if not self.is_connected:
            port = self.cb_ports.get()
            if not port:
                messagebox.showwarning("경고", "COM 포트를 선택하세요.")
                return
            try:
                self.serial_port = serial.Serial(port, 9600, timeout=0.1, write_timeout=1)
                self.is_connected = True
                self.parser = UartFrameParser()
                self.received_frames = 0
                self.received_bytes = 0
                self.last_distance = None
                self.last_threshold = None
                self.distance_text.set("Distance: ----")
                self.threshold_text.set("Threshold: ----")
                self.link_text.set("통신: 포트 연결됨 · 보드 응답 대기")
                self.btn_connect.config(text="해제", bg="#F44336")
                self.log(f"{port} 포트에 연결되었습니다.", "blue")
                self.cb_ports.config(state="disabled")

                # 수신 스레드 시작
                self.rx_thread = threading.Thread(target=self.receive_loop, args=(self.serial_port,), daemon=True)
                self.rx_thread.start()
                self.request_status()
                self.root.after(2000, self._check_initial_response, self.serial_port)
            except Exception as e:
                messagebox.showerror("오류", f"포트 연결 실패:\n{e}")
        else:
            self.is_connected = False
            if self.stop_pending:
                self._finish_stop(False, "연결 해제 · 보드 정지 미확인")
            if self.serial_port and self.serial_port.is_open:
                self.serial_port.close()
            self.btn_connect.config(text="연결", bg="#4CAF50")
            self.cb_ports.config(state="readonly")
            self.log("연결이 해제되었습니다.", "red")
            self.link_text.set("통신: 연결 해제")

    def request_status(self):
        """접속 전에 보낸 Threshold를 놓쳐도 현재 상태를 다시 요청한다."""
        return self._send_text_cmd("read")

    def _check_initial_response(self, port):
        if self.is_connected and self.serial_port is port and self.received_frames == 0:
            detail = "수신 바이트가 있으나 유효 프레임 없음" if self.received_bytes else "보드 수신 없음"
            self.link_text.set(f"통신: {detail} · Zynq 비트스트림/ARM 브릿지 확인")
            self.log(f"{detail}: 포트 연결만으로는 보드 통신이 확인되지 않습니다.", "red")

    def encode_uart_frame(self, frame_type, payload: bytes):
        length = len(payload)
        crc = frame_type ^ length
        for b in payload:
            crc ^= b
        crc &= 0xFF
        return bytes([UART_FRAME_SOF, frame_type, length]) + payload + bytes([crc])

    def _send_text_cmd(self, cmd_text: str):
        """CMD 프레임으로 문자열 송신하는 공통 로직"""
        if not self.is_connected or not self.serial_port:
            messagebox.showwarning("경고", "먼저 포트를 연결하세요.")
            return False

        payload = cmd_text.encode('utf-8')
        if len(payload) > 28:
            messagebox.showwarning("경고", "명령어는 28바이트를 초과할 수 없습니다.")
            return False

        frame_bytes = self.encode_uart_frame(UART_TYPE_CMD, payload)

        try:
            written = self.serial_port.write(frame_bytes)
            if written != len(frame_bytes):
                raise IOError(f"부분 송신: {written}/{len(frame_bytes)} bytes")
            self.log(f"→ [송신] CMD : {cmd_text}")
            return True
        except Exception as e:
            self.log(f"송신 오류: {e}")
            return False

    def send_cmd(self):
        cmd_text = self.ent_cmd.get().strip()
        if not cmd_text:
            return
        if cmd_text.lower() == "stop":
            self.send_stop()
            self.ent_cmd.delete(0, tk.END)
            return
        if self._send_text_cmd(cmd_text):
            self.ent_cmd.delete(0, tk.END)  # 입력창 지우기

    def send_stop(self):
        """보드의 PW:OK_PC 응답을 받은 뒤에만 정지 성공으로 표시한다."""
        if self.stop_pending:
            return
        if self._send_text_cmd("stop"):
            self.stop_pending = True
            self.stop_text.set("STOP: 보드 정지 확인 대기")
            self.btn_stop.config(state="disabled")
            self.stop_timeout_id = self.root.after(2000, self._stop_timed_out)

    def _stop_timed_out(self):
        self.stop_timeout_id = None
        if self.stop_pending:
            self._finish_stop(False, "응답 없음 · 보드 정지 미확인")

    def _finish_stop(self, confirmed, message=None):
        if self.stop_timeout_id is not None:
            self.root.after_cancel(self.stop_timeout_id)
            self.stop_timeout_id = None
        self.stop_pending = False
        self.btn_stop.config(state="normal")
        if confirmed:
            self.stop_text.set("STOP: 보드 경보 해제 확인")
            self.deactivate_alarm()
        else:
            detail = message or "보드 정지 미확인"
            self.stop_text.set(f"STOP: {detail}")
            self.log(detail, "red")

    # --- [알람 상태 제어] ---
    def activate_alarm(self, sensed_dist=None):
        if sensed_dist is not None and sensed_dist > 0:
            self.first_sensed_dist = sensed_dist
        elif self.last_distance is not None and self.last_distance > 0 and self.first_sensed_dist is None:
            self.first_sensed_dist = self.last_distance

        dist_str = f"{self.first_sensed_dist} cm" if (self.first_sensed_dist is not None and self.first_sensed_dist > 0) else ""

        if not self.is_alarm_active:
            self.is_alarm_active = True
            self.btn_alarm.pack(side="left", padx=10)  # 알람 버튼 나타남

        if dist_str:
            self.btn_alarm.config(text=f"ALARM ({dist_str})")
        else:
            self.btn_alarm.config(text="ALARM")

    def deactivate_alarm(self):
        if not self.is_alarm_active:
            return
        self.is_alarm_active = False
        self.first_sensed_dist = None
        self.btn_alarm.config(text="ALARM")
        self.btn_alarm.pack_forget()  # 알람 버튼 숨김
        self.log("알람 상태 해제 (상시 감시 복귀)")

    def receive_loop(self, port):
        while self.is_connected and self.serial_port is port:
            try:
                if port.in_waiting:
                    raw_data = port.read(port.in_waiting)
                    self.received_bytes += len(raw_data)
                    for byte in raw_data:
                        frame = self.parser.feed(byte)
                        if frame:
                            # Tkinter는 메인 스레드에서만 UI를 안전하게 갱신할 수 있으므로
                            # after()를 통해 메인 스레드로 처리를 넘긴다.
                            self.root.after(0, self.process_received_frame, frame)
            except Exception as e:
                if self.is_connected:  # 의도적인 종료가 아닌 에러일 경우
                    self.root.after(0, self._receive_failed, port, str(e))
                break
            time.sleep(0.01)

    def _receive_failed(self, port, message):
        if self.is_connected and self.serial_port is port:
            self.log(f"수신 에러: {message}", "red")
            self.toggle_connection()

    def process_received_frame(self, frame):
        f_type = frame['type']
        payload_str = frame['payload'].decode('utf-8', errors='ignore')
        self.received_frames += 1
        self.link_text.set("통신: 유효한 보드 응답 수신")

        if f_type == UART_TYPE_DATA:
            self.log(f"← [수신] DATA : {payload_str}")
        elif f_type == UART_TYPE_ACK:
            self.log(f"← [수신] ACK  : {payload_str}")
        elif f_type == UART_TYPE_ERR:
            self.log(f"← [수신] ERR  : {payload_str}")
        else:
            self.log(f"← [수신] UNKNOWN(0x{f_type:02X}) : {payload_str}")

        # 펌웨어/FPGA RTL이 보내는 상태 메시지를 해석하여 알람 여부를 판단한다.
        if f_type == UART_TYPE_DATA:
            self._handle_status_message(payload_str)

    def _handle_status_message(self, payload_str: str):
        if payload_str in ("MD:GUARD", "SYS:START"):
            self.mode_guard = True

        elif payload_str == "MD:NORMAL":
            self.mode_guard = False
            self.last_distance = None
            self.last_threshold = None
            self.deactivate_alarm()

        elif payload_str in ("PW:OK_PC", "PW:OK_NRM"):
            # 터치 키패드 비밀번호 또는 PC 명령으로 알람 해제 -> 상시 감시 유지
            self.mode_guard = True
            if payload_str == "PW:OK_PC":
                self._finish_stop(True)
            else:
                self.deactivate_alarm()

        elif payload_str == "Intruder detection":
            # FPGA 침입 감지 시 1회 전송되는 패킷
            self.activate_alarm()

        elif payload_str.startswith("ALERT:"):
            # 호환용 ALERT 패킷 처리
            _, _, val_str = payload_str.partition(':')
            if val_str.isdigit():
                sensed = int(val_str)
                self.activate_alarm(sensed)

        elif ':' in payload_str:
            # "Distance:0056", "Threshold:0056" 형태의 센서 값 처리
            tag, _, value_str = payload_str.partition(':')
            if value_str.isdigit():
                value = int(value_str)
                if tag == "Distance":
                    self.last_distance = value
                    suffix = "100cm 이상/미측정" if value == 0 else f"{value} cm"
                    self.distance_text.set(f"Distance:{value:04d} ({suffix})")
                    if self.is_alarm_active and value > 0 and (self.first_sensed_dist is None or self.first_sensed_dist == 0):
                        self.activate_alarm(value)
                elif tag == "Threshold":
                    self.last_threshold = value
                    suffix = "경보 비활성" if value == 0 else f"{value} cm"
                    self.threshold_text.set(f"Threshold:{value:04d} ({suffix})")
                elif tag == "Alarm" and value in (0, 1):
                    if value:
                        self.activate_alarm()
                    else:
                        self.deactivate_alarm()

if __name__ == "__main__":
    root = tk.Tk()
    app = UartRepeaterApp(root)
    root.mainloop()
