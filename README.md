# UART DHT11 Stopwatch Project

## 프로젝트 개요

UART 송수신 기능에 DHT11 온습도 센서와 Stopwatch/Watch 기능을 결합한 FPGA 응용 프로젝트입니다.

## 목표 동작

- DHT11 센서에서 온습도 데이터를 읽어옵니다.
- Stopwatch/Watch datapath가 시간 값을 생성하고 FND에 표시합니다.
- UART RX/TX를 통해 외부 장치와 데이터를 주고받습니다.
- ASCII encoder/decoder를 사용해 UART 데이터와 내부 표시 데이터를 연결합니다.

## 기술 스택

| 구분 | 내용 |
| --- | --- |
| 핵심 개념 | UART, baud tick, FIFO 없는 단순 송수신, DHT11 one-wire timing, stopwatch, FND scan |
| 사용 장비 | Basys3 FPGA, DHT11 센서, 7-segment FND |
| 사용 언어 | Verilog |
| 개발 도구 | Vivado, HDL simulation testbench |

## 시스템 구조

```text
uart_top
├─ baud_tick
├─ uart_rx
├─ uart_tx
├─ ascii_decoder
└─ ascii_encoder

top_stopwatch_watch
├─ control_unit
├─ stopwatch_datapath
├─ watch_datapath
├─ tick_gen_100hz
├─ fnd_controller
└─ btn_debounce

dht11_controller
└─ tick_gen
```

- `uart_top`: UART RX/TX와 ASCII 변환 흐름을 연결하는 통신 탑 모듈입니다.
- `baud_tick`: UART bit timing 기준 tick을 생성합니다.
- `uart_rx`, `uart_tx`: serial RX/TX line을 parallel data와 변환합니다.
- `ascii_decoder`, `ascii_encoder`: UART로 주고받는 ASCII 데이터를 내부 데이터 형식과 변환합니다.
- `dht11_controller`: DHT11 start signal, response, data bit timing을 처리합니다.
- `top_stopwatch_watch`: stopwatch/watch 모드 제어와 시간 datapath, FND 출력을 통합합니다.
- `fnd_controller`: 시간 또는 센서 값을 7-segment 표시 신호로 변환합니다.

## 검증 방식

- `tb_uart_loop_back`에서 UART 송수신 loopback 동작을 확인할 수 있습니다.
