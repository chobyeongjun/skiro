import sys, json, re, hashlib

try:
    raw = sys.stdin.buffer.read()
    d = json.loads(raw.decode('utf-8', errors='replace'), strict=False)
except:
    sys.exit(0)

val = d.get('message', d.get('prompt', d.get('content', d.get('text', ''))))
if isinstance(val, list):
    val = ' '.join(b.get('text', '') for b in val if isinstance(b, dict))
val = str(val)
msg = val.lower()

if len(msg.strip()) < 15:  # 너무 짧은 입력 무시
    sys.exit(0)

# 노이즈 필터: 명령/요청/감정 표현은 교훈이 아님
noise_patterns = [
    r'^@local',           # @local 명령
    r'^vault/',           # vault 경로 언급
    r'^git ',             # git 명령
    r'해줘$|해라$|하자$|하세요$|해주세요$|시켜$',  # 요청문
    r'읽어$|확인해$|보여줘$|알려줘$',            # 조회 요청
    r'MORNING|BRIEFING|briefing',
    r'obsidian.*정리|정리.*obsidian',
    r'기억을 못|이전의 내역',                    # 시스템 불만
    r'^\d+\)',            # 번호 매기기 시작
    r'봐봐$|봐줘$|봐라$|확인해봐$|체크해봐$',  # 점검 요청
    r'있나\s*봐|없나\s*봐|되나\s*봐',          # 확인 요청
    r'<ide_opened|<task-notification',
    r'chobb0@|hobb0@',
    r'files changed|insertions\(\+\)',
]
if any(re.search(p, msg) for p in noise_patterns):
    sys.exit(0)

sentences = re.split(r'[.!?\n。！？]', val)
first = next((s.strip() for s in sentences if s.strip()), val)[:80]
msg_hash = hashlib.md5(msg.encode()).hexdigest()

PROB = [
    # 한국어
    '안됐어','안됩니다','안되네','안되는','실패했어','실패함','실패했',
    '에러','오류','버그','이상하게','이상한데','이상해','이상함',
    '안 되더라','안되더라','동작 안 해','동작 안 함',
    '작동 안 해','작동 안 함','문제 생겼','문제가 있',
    '점프했어','튀어','튀는데','안 됐어','안됐','안 돼',
    '발생했','발생해','터졌어','죽었어','멈췄어','먹통',
    '안돼','빌드가 안','컴파일 에러','컴파일이 안',
    '연결이 안','응답이 없','충돌','끊겨','끊켰',
    '인식 못','인식이 안','인식 불량','탔어','타버렸','과전압','과전류',
    '망가졌','고장','깨졌','날아갔',
    # 영어
    'not working','doesnt work','does not work',"doesn't work",
    'failed','error','errors','bug','bugs',
    'broken','crashed','unexpected','wrong output',
    'issue','issues','problem','wrong','jump',
    'fault','hang','freeze','timeout','overflow','leak',
    'segfault','segmentation','undefined reference',
    'build failed','compilation failed','cannot connect',
    'no response','not responding','mismatch','collision',
]
SOL = [
    # 한국어
    '해결됐어','해결됐다','해결됐습니다','해결됩니다',
    '이렇게 하니까','이렇게 하면 돼','이렇게 하면 됩니다',
    '알고 보니','알고보니','알고보면','알고 보면',
    'fix는','해결책은','방법은','해결방법은',
    '정상 작동합니다','정상 작동해','작동이 됩니다',
    '해결했어','해결했다','해결했습니다',
    '고쳤어','고쳤다','고쳐졌어','고쳐졌다',
    '됐어요','해결된 것 같아','해결된 것 같습니다',
    # 영어
    'fixed','solved','it works now','it works','problem solved',
    'the fix is','turns out','working now','working again',
    'resolved','figured out','the solution','solution is',
    'managed to','got it working',
]

is_p = int(any(p in msg for p in PROB))
is_s = int(any(p in msg for p in SOL))

# 문제+해결 동시: 부정적 표현이 강하면 문제 우선
if is_p and is_s:
    neg_strong = any(p in msg for p in ['still','아직','또','다시','여전히','계속'])
    if neg_strong:
        is_s = 0

cat = 'process'
if any(p in msg for p in ['motor','모터','actuator','액추에이터','enable','gpio','adc','dac','pwm','encoder','로드셀','loadcell','servo','servomotor']): cat = 'hardware'
if any(p in msg for p in ['can bus','can 통신','can_','uart','spi','i2c','rs232','rs485','modbus','serial port','protocol','통신 에러','패킷']): cat = 'protocol'
if any(p in msg for p in ['pid','gain','kp','kd','ki','impedance','admittance','ilc','제어','controller','control loop','trajectory','궤적']): cat = 'control'
if any(p in msg for p in ['isr','interrupt','인터럽트','dma','rtos','freertos','mutex','semaphore','deadlock','race condition','stack overflow']): cat = 'software'
if any(p in msg for p in ['flash','upload','firmware','펌웨어','전원','power supply','overvolt','overcurr','safety','안전']): cat = 'safety'

sev = 'WARNING'
if any(p in msg for p in ['motor','모터','flash','전원','safety','안전','fire','burn','smoke','data loss','폭발','연기']): sev = 'CRITICAL'
if any(p in msg for p in ['사소','minor','typo','cosmetic','print문','로그','debug','주석']): sev = 'INFO'

print(f"{msg_hash}|{is_p}|{is_s}|{cat}|{sev}|{first}")
