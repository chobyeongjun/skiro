# p2-zed.md — ZED SDK 기반 3D 추적
# skiro-mocap | ZED 트리거 시 | ~580 tok

## ZED X Mini 초기화 (Jetson, GMSL2)

```python
import pyzed.sl as sl

def init_zed_xmini(resolution='HD1080', fps=30):
    """
    ZED X Mini 지원 해상도: HD1080, HD1200 (HD720 미지원)
    """
    cam = sl.Camera()
    
    init_params = sl.InitParameters()
    init_params.camera_resolution = {
        'HD1080': sl.RESOLUTION.HD1080,
        'HD1200': sl.RESOLUTION.HD1200,
    }[resolution]
    init_params.camera_fps = fps
    init_params.coordinate_units = sl.UNIT.METER
    init_params.coordinate_system = sl.COORDINATE_SYSTEM.RIGHT_HANDED_Y_UP
    init_params.depth_mode = sl.DEPTH_MODE.ULTRA
    
    err = cam.open(init_params)
    if err != sl.ERROR_CODE.SUCCESS:
        raise RuntimeError(f"ZED open failed: {err}")
    
    return cam

def get_3d_point_from_pixel(cam, image, depth, u, v):
    """
    픽셀 좌표 (u, v) → 3D 좌표 (미터)
    YOLO26s 감지 결과의 bbox 중심점 → 3D
    """
    point_cloud = sl.Mat()
    cam.retrieve_measure(point_cloud, sl.MEASURE.XYZRGBA)
    
    x, y, z, _ = point_cloud.get_value(u, v)
    if any(np.isnan([x, y, z])):
        return None
    return np.array([x, y, z])  # 미터
```

## YOLO26s + ZED 포즈 추정 (H-Walker)

```python
from ultralytics import YOLO
import numpy as np

class PoseEstimator3D:
    """
    2D YOLO26s 키포인트 → ZED 포인트 클라우드 → 3D 관절 좌표
    MediaPipe 미사용 (상반신 필요 없음, 발 위치만 필요)
    """
    KEYPOINT_MAP = {
        'left_ankle':  15,
        'right_ankle': 16,
        'left_knee':   13,
        'right_knee':  14,
        'left_hip':    11,
        'right_hip':   12,
    }
    
    def __init__(self, model_path='yolo26s-pose.pt', conf=0.5):
        self.model = YOLO(model_path)
        self.conf = conf
    
    def estimate(self, rgb_frame, depth_cam):
        """
        rgb_frame: (H, W, 3) uint8
        depth_cam: sl.Camera
        Returns: dict {joint_name: np.array([x, y, z])}
        """
        results = self.model(rgb_frame, conf=self.conf, verbose=False)
        joints_3d = {}
        
        if len(results) == 0 or results[0].keypoints is None:
            return joints_3d
        
        kpts = results[0].keypoints.xy[0].cpu().numpy()  # (17, 2)
        
        for joint_name, idx in self.KEYPOINT_MAP.items():
            u, v = int(kpts[idx, 0]), int(kpts[idx, 1])
            pt = get_3d_point_from_pixel(depth_cam, None, None, u, v)
            if pt is not None:
                joints_3d[joint_name] = pt
        
        return joints_3d

# ZED S/N: 52277959
# reset_zed alias: ~/.bashrc에 등록됨
```
