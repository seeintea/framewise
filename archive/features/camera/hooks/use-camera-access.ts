import { useCameraPermissions } from 'expo-camera';
import {
  type GranularPermission,
  usePermissions as useMediaLibraryPermissions,
} from 'expo-media-library';
import { useCallback } from 'react';
import { Alert, Linking } from 'react-native';

import { logError, logInfo } from '@/logging';

const PHOTO_PERMISSION_OPTIONS = {
  granularPermissions: ['photo'] satisfies GranularPermission[],
  writeOnly: true,
};

export function useCameraAccess() {
  const [cameraPermission, requestCameraPermission] = useCameraPermissions();
  const [photoPermission, requestPhotoPermission] = useMediaLibraryPermissions(
    PHOTO_PERMISSION_OPTIONS,
  );

  return useCallback(async () => {
    try {
      const nextCameraPermission = cameraPermission?.granted
        ? cameraPermission
        : await requestCameraPermission();

      if (!nextCameraPermission.granted) {
        logInfo('permissions', 'camera_denied', {
          canAskAgain: nextCameraPermission.canAskAgain,
        });
        showPermissionAlert('相机', nextCameraPermission.canAskAgain);
        return false;
      }

      logInfo('permissions', 'camera_granted');
      const nextPhotoPermission = photoPermission?.granted
        ? photoPermission
        : await requestPhotoPermission();

      if (!nextPhotoPermission.granted) {
        logInfo('permissions', 'photo_library_denied', {
          canAskAgain: nextPhotoPermission.canAskAgain,
        });
        showPermissionAlert('照片存储', nextPhotoPermission.canAskAgain);
        return false;
      }

      logInfo('permissions', 'photo_library_granted');
      return true;
    } catch (error) {
      logError('permissions', 'permission_check_failed', error);
      Alert.alert(
        '无法检查权限',
        error instanceof Error ? error.message : '请稍后重试',
      );
      return false;
    }
  }, [
    cameraPermission,
    photoPermission,
    requestCameraPermission,
    requestPhotoPermission,
  ]);
}

function showPermissionAlert(permissionName: string, canAskAgain: boolean) {
  Alert.alert(
    `需要${permissionName}权限`,
    `请允许 Framewise 使用${permissionName}权限后再进入相机。`,
    canAskAgain
      ? [{ text: '知道了' }]
      : [
          { text: '取消', style: 'cancel' },
          {
            text: '打开设置',
            onPress: () => void Linking.openSettings(),
          },
        ],
  );
}
