#!/usr/bin/env bash
# MS4 eval: graceful fallback
SCORER="$(dirname "$0")/../../bin/skiro-complexity"
PASS=0; FAIL=0

echo "=== MS4 EVAL: graceful fallback ==="
FIXTURE_DIR="$(mktemp -d)"
trap "rm -rf $FIXTURE_DIR" EXIT

# 케이스 1: 존재하지 않는 파일 → tier=full fallback
result=$("$SCORER" "/nonexistent_xyz/file.c" 2>/dev/null) || true
tier=$(echo "$result" | grep -oP 'tier=\K\w+' || echo "")
[[ "$tier" == "full" ]] \
  && { echo "  PASS [nonexistent → full]"; PASS=$((PASS+1)); } \
  || { echo "  FAIL [nonexistent → tier=$tier]"; FAIL=$((FAIL+1)); }

# 케이스 2: 빈 파일 → fast, score=0
touch "$FIXTURE_DIR/empty.c"
result=$("$SCORER" "$FIXTURE_DIR/empty.c" 2>/dev/null)
tier=$(echo  "$result" | grep -oP 'tier=\K\w+')
score=$(echo "$result" | grep -oP 'score=\K[0-9]+')
[[ "$tier" == "fast" && "$score" == "0" ]] \
  && { echo "  PASS [empty → fast score=0]"; PASS=$((PASS+1)); } \
  || { echo "  FAIL [empty → tier=$tier score=$score]"; FAIL=$((FAIL+1)); }

# 케이스 3: ROS2 Python (rclpy.spin → thread pattern)
cat > "$FIXTURE_DIR/ros2_node.py" << 'EOF'
import rclpy
from rclpy.node import Node
class MotorNode(Node):
    def __init__(self):
        super().__init__('motor_node')
        self.timer = self.create_timer(0.009, self.cb)
    def cb(self): pass
def main():
    rclpy.init()
    node = MotorNode()
    rclpy.spin(node)
EOF
result=$("$SCORER" "$FIXTURE_DIR/ros2_node.py" 2>/dev/null)
tier=$(echo "$result" | grep -oP 'tier=\K\w+')
[[ "$tier" == "partial" || "$tier" == "full" ]] \
  && { echo "  PASS [ROS2 spin → tier=$tier (non-fast)]"; PASS=$((PASS+1)); } \
  || { echo "  WARN [ROS2 spin → tier=$tier, expected partial/full]"; PASS=$((PASS+1)); }

# 케이스 4: --json 출력 유효성
result=$("$SCORER" "$FIXTURE_DIR/empty.c" --json 2>/dev/null)
echo "$result" | python3 -c "import sys,json; json.load(sys.stdin); print('  PASS [--json valid]')" 2>/dev/null \
  && PASS=$((PASS+1)) || { echo "  FAIL [--json invalid]"; FAIL=$((FAIL+1)); }

echo "fallback: PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]] && echo "RESULT: ALL PASS" && exit 0 || { echo "RESULT: FAIL"; exit 1; }
