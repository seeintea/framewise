import { useCameraPermissions } from 'expo-camera';
import {
  type GranularPermission,
  usePermissions as useMediaLibraryPermissions,
} from 'expo-media-library';
import { router } from 'expo-router';
import { Alert, Linking } from 'react-native';

import { Templates } from '@/features/templates';
import { diagnosticsEnabled, logError, logInfo } from '@/logging';

const FEATURED_PRESET_ID = 'classic-rule-of-thirds';
const PHOTO_PERMISSION_OPTIONS = {
  granularPermissions: ['photo'] satisfies GranularPermission[],
  writeOnly: true,
};

export default function TemplatesRoute() {
  const [cameraPermission, requestCameraPermission] = useCameraPermissions();
  const [photoPermission, requestPhotoPermission] = useMediaLibraryPermissions(
    PHOTO_PERMISSION_OPTIONS,
  );

  async function openCamera(presetId: string) {
    logInfo('templates', 'camera_requested', { presetId });

    try {
      const nextCameraPermission = cameraPermission?.granted
        ? cameraPermission
        : await requestCameraPermission();

      if (!nextCameraPermission.granted) {
        logInfo('permissions', 'camera_denied', {
          canAskAgain: nextCameraPermission.canAskAgain,
        });
        showPermissionAlert('相机', nextCameraPermission.canAskAgain);
        return;
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
        return;
      }

      logInfo('permissions', 'photo_library_granted');
      logInfo('templates', 'camera_navigation_started', { presetId });
      router.push({ pathname: '/camera', params: { presetId } });
    } catch (error) {
      logError('permissions', 'permission_check_failed', error, { presetId });
      Alert.alert(
        '无法检查权限',
        error instanceof Error ? error.message : '请稍后重试',
      );
    }
  }

  return (
    <Templates
      onOpenDiagnostics={
        diagnosticsEnabled ? () => router.push('../diagnostics') : undefined
      }
      onOpenFeatured={() => void openCamera(FEATURED_PRESET_ID)}
      onSelectTemplate={(presetId) => void openCamera(presetId)}
    />
  );
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
