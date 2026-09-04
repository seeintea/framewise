import { useCameraPermissions } from 'expo-camera';
import {
  type GranularPermission,
  usePermissions as useMediaLibraryPermissions,
} from 'expo-media-library';
import { router } from 'expo-router';
import { Alert, Linking } from 'react-native';

import { Templates } from '@/features/templates';

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
    try {
      const nextCameraPermission = cameraPermission?.granted
        ? cameraPermission
        : await requestCameraPermission();

      if (!nextCameraPermission.granted) {
        showPermissionAlert('相机', nextCameraPermission.canAskAgain);
        return;
      }

      const nextPhotoPermission = photoPermission?.granted
        ? photoPermission
        : await requestPhotoPermission();

      if (!nextPhotoPermission.granted) {
        showPermissionAlert('照片存储', nextPhotoPermission.canAskAgain);
        return;
      }

      router.push({ pathname: '/camera', params: { presetId } });
    } catch (error) {
      Alert.alert(
        '无法检查权限',
        error instanceof Error ? error.message : '请稍后重试',
      );
    }
  }

  return (
    <Templates
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
