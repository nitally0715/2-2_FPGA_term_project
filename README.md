# 🎰 FPGA Roulette Game  
### 18조 – FPGA Casino Roulette Project

본 프로젝트는 **2HBE-Combo II-DLD FPGA 보드**를 활용하여  
**카지노 룰렛(Casino Roulette)** 시스템을 하드웨어적으로 구현하는 프로젝트입니다.

---

## 📌 프로젝트 소개

이 프로젝트의 목표는 다음과 같습니다:

- FPGA 기반의 인터랙티브 게임 구현  
- **Keypad 입력**, **LCD Display**, **7-Segment**, **LED**, **Piezo** 등  
  다양한 모듈을 조합하여 하드웨어 게임 시스템 구축
- FSM(Finite State Machine) 기반의 단계적 게임 로직 설계
- 실제 룰렛 게임의 **베팅 시스템**, **확률**, **배수 시스템**을 재현

---

## 🎮 게임 흐름 요약

### 1️⃣ 시작 화면  
- LCD: **“PRESS STAR TO START”**  
- 기본 자본: **100 coin**
- 7-Segment에 현재 자본 표시

### 2️⃣ 베팅 금액 설정  
- Keypad 숫자 입력으로 베팅 금액 입력  
- 최대 보유 금액까지 입력 가능  
- 잘못 입력 → LCD 경고 메시지  
- `#` : 초기화  
- `*` : 다음 단계

### 3️⃣ 베팅 개수 설정  
- 선택 가능한 숫자 개수: **1 ~ 8개**  
- 개수가 적을수록 당첨확률은 낮지만 배수는 커짐

| 선택 개수 | 당첨 확률 | 배수 |
|-----------|-----------|------|
| 1개       | 12.5%     | x8   |
| 2개       | 25%       | x4   |
| 4개       | 50%       | x2   |

오
---

## 📎 Repository 구조 예시

```
/fpga-roulette
 ├── src/
 │    ├── fsm.v
 │    ├── keypad.v
 │    ├── lcd.v
 │    ├── seven_seg.v
 │    ├── piezo.v
 │    └── roulette_core.v
 ├── docs/
 │    ├── schema.png
 │    ├── fsm_diagram.png
 │    └── presentation.pdf
 ├── README.md
 └── LICENSE
```

---

## 🔧 개발 환경

- **Vivado 2020+**
- **2HBE-Combo II-DLD FPGA Board**
- **Verilog HDL**

---
