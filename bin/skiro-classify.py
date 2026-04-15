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

if len(msg.strip()) < 15:
    sys.exit(0)

# 노이즈 필터
noise_patterns = [
    r'^@local', r'^vault/', r'^git ',
    r'해줘$|해라$|하자$|하세요$|해주세요$|시켜$',
    r'읽어$|확인해$|보여줘$|알려줘$',
    r'MORNING|BRIEFING|briefing',
    r'obsidian.*정리|정리.*obsidian',
    r'기억을 못|이전의 내역',
    r'^\d+\)',
    r'봐봐$|봐줘$|봐라$|확인해봐$|체크해봐$',
    r'있나\s*봐|없나\s*봐|되나\s*봐',
    r'<ide_opened|<task-notification',
    r'chobb0@|hobb0@',
    r'files changed|insertions\(\+\)',
    r'추가해야할|추가해야 할|구조를 바꾸',  # 시스템 개선 요청
]
if any(re.search(p, msg) for p in noise_patterns):
    sys.exit(0)

# 문장 분리: 숫자 뒤의 .은 소수점이므로 제외
sentences = re.split(r'(?<!\d)[.!?\n。！？](?!\d)', val)
first = next((s.strip() for s in sentences if s.strip()), val)[:120]
msg_hash = hashlib.md5(msg.encode()).hexdigest()

# === Signal Detection ===

PROB = [
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
    '해결됐어','해결됐다','해결됐습니다','해결됩니다',
    '이렇게 하니까','이렇게 하면 돼','이렇게 하면 됩니다',
    '알고 보니','알고보니','알고보면','알고 보면',
    'fix는','해결책은','방법은','해결방법은',
    '정상 작동합니다','정상 작동해','작동이 됩니다',
    '해결했어','해결했다','해결했습니다',
    '고쳤어','고쳤다','고쳐졌어','고쳐졌다',
    '됐어요','해결된 것 같아','해결된 것 같습니다',
    'fixed','solved','it works now','it works','problem solved',
    'the fix is','turns out','working now','working again',
    'resolved','figured out','the solution','solution is',
    'managed to','got it working',
]

# REWARD: 잘 됐다, 좋다, 완벽, 성공 — "왜 잘 됐는지" 패턴
REWARD = [
    '잘 돼','잘 됐','잘됐','잘된다','잘 작동','잘작동',
    '완벽해','완벽하게','성공했','성공적',
    '좋아졌','좋아요','좋네','훨씬 나아','빨라졌','깔끔해',
    '안정적','안정적으로','정확하게 작동','정확해',
    '이게 맞아','이게 정답','이 방법이 맞','이렇게 하는 게 맞',
    '이 설정이 좋','이 값이 좋','이 조합이 좋',
    'works great','works perfectly','much better','stable',
    'this is correct','this works','good result','perfect',
    'accurate','reliable','fast enough','clean output',
]

# PUNISH: 왜 안 됐는지에 대한 원인 분석 패턴 (문제와 다름 — 원인 설명)
PUNISH = [
    '때문에 안','때문에 실패','이유는','원인은',
    '이래서 안','그래서 안','이러면 안','하면 안 되는',
    '절대 하면 안','이건 쓰면 안','이 방법은 안',
    '이렇게 하면 망','이러면 망','이건 위험',
    '이 값은 위험','이 설정은 안','오히려 더 나빠',
    'because of','the reason','root cause','caused by',
    'never do this','dont use','avoid this','dangerous',
    'this approach fails','this breaks','worse than',
]

is_p = int(any(p in msg for p in PROB))
is_s = int(any(p in msg for p in SOL))
is_r = int(any(p in msg for p in REWARD))  # reward signal
is_x = int(any(p in msg for p in PUNISH))  # punish signal

# 우선순위: reward > solution > problem > punish
# reward+solution 동시 → reward (긍정 강화)
# problem+punish 동시 → punish (원인 분석)
if is_p and is_s:
    neg_strong = any(p in msg for p in ['still','아직','또','다시','여전히','계속'])
    if neg_strong:
        is_s = 0

# 카테고리
cat = 'process'
if any(p in msg for p in ['motor','모터','actuator','액추에이터','enable','gpio','adc','dac','pwm','encoder','로드셀','loadcell','servo']): cat = 'hardware'
if any(p in msg for p in ['can bus','can 통신','can_','uart','spi','i2c','rs232','rs485','modbus','serial port','protocol','통신 에러','패킷']): cat = 'protocol'
if any(p in msg for p in ['pid','gain','kp','kd','ki','impedance','admittance','ilc','제어','controller','control loop','trajectory','궤적']): cat = 'control'
if any(p in msg for p in ['isr','interrupt','인터럽트','dma','rtos','freertos','mutex','semaphore','deadlock','race condition','stack overflow']): cat = 'software'
if any(p in msg for p in ['flash','upload','firmware','펌웨어','전원','power supply','overvolt','overcurr','safety','안전']): cat = 'safety'

sev = 'WARNING'
if any(p in msg for p in ['motor','모터','flash','전원','safety','안전','fire','burn','smoke','data loss','폭발','연기']): sev = 'CRITICAL'
if any(p in msg for p in ['사소','minor','typo','cosmetic','print문','로그','debug','주석']): sev = 'INFO'

# Output format: hash|is_problem|is_solution|is_reward|is_punish|category|severity|first_sentence
print(f"{msg_hash}|{is_p}|{is_s}|{is_r}|{is_x}|{cat}|{sev}|{first}")
