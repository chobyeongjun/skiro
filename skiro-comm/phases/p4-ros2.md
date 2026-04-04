# p4-ros2.md — ROS2/DDS 통신 가이드
# skiro-comm | ROS2 트리거 시 | ~560 tok

## ROS2 노드 기본 구조 (C++)

```cpp
#include "rclcpp/rclcpp.hpp"
#include "std_msgs/msg/float64_multi_array.hpp"

class MotorController : public rclcpp::Node {
public:
    MotorController() : Node("motor_controller") {
        // Publisher
        cmd_pub_ = create_publisher<std_msgs::msg::Float64MultiArray>(
            "/motor/cmd", 10);
        // Subscriber
        state_sub_ = create_subscription<std_msgs::msg::Float64MultiArray>(
            "/motor/state", 10,
            std::bind(&MotorController::state_callback, this, std::placeholders::_1));
        // Timer (111Hz)
        timer_ = create_wall_timer(
            std::chrono::milliseconds(9),
            std::bind(&MotorController::control_loop, this));
    }
private:
    void control_loop() { /* 제어 루프 */ }
    void state_callback(const std_msgs::msg::Float64MultiArray::SharedPtr msg) {}
    rclcpp::Publisher<std_msgs::msg::Float64MultiArray>::SharedPtr cmd_pub_;
    rclcpp::Subscription<std_msgs::msg::Float64MultiArray>::SharedPtr state_sub_;
    rclcpp::TimerBase::SharedPtr timer_;
};
```

## H-Walker ROS2 토픽 구조 (hw_common 표준)

```
/hw/motor/cmd          Float64MultiArray  # [id, kp, kd, pos, vel, tau] × N
/hw/motor/state        Float64MultiArray  # [id, pos, vel, current] × N
/hw/gait/phase         Int32              # 0:swing, 1:stance
/hw/perception/pose    PoseArray          # YOLO26s 관절 위치
/hw/load_cell/force    Float64MultiArray  # [FL, FR, RL, RR] N
/hw/imu/data           Imu                # sensor_msgs/Imu
```

## QoS 설정

```cpp
// 실시간 제어 (손실 허용, 최신 데이터만)
rclcpp::QoS qos_realtime(1);
qos_realtime.best_effort().durability_volatile();

// 상태 기록 (신뢰성 보장)
rclcpp::QoS qos_reliable(10);
qos_reliable.reliable().durability_volatile();
```

## 일반 디버깅

```bash
ros2 topic list
ros2 topic echo /hw/motor/state
ros2 topic hz /hw/motor/cmd      # 주파수 확인
ros2 topic delay /hw/motor/cmd   # 지연 확인
ros2 node info /motor_controller
```
