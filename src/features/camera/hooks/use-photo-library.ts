import * as ImagePicker from 'expo-image-picker';
import * as IntentLauncher from 'expo-intent-launcher';
import {
  AssetField,
  type GranularPermission,
  MediaType,
  Query,
  usePermissions,
} from 'expo-media-library';
import { useCallback, useEffect, useState } from 'react';
import { Platform } from 'react-native';

import { logError } from '@/logging';

const PHOTO_PERMISSION_OPTIONS = {
  granularPermissions: ['photo'] satisfies GranularPermission[],
  writeOnly: false,
};

export function usePhotoLibrary() {
  const [permission] = usePermissions(PHOTO_PERMISSION_OPTIONS);
  const [latestPhotoUri, setLatestPhotoUri] = useState<string>();

  const refreshLatestPhoto = useCallback(async () => {
    setLatestPhotoUri(await getLatestPhotoUri());
  }, []);

  useEffect(() => {
    if (!permission?.granted) {
      return;
    }

    void getLatestPhotoUri()
      .then(setLatestPhotoUri)
      .catch((error: unknown) =>
        logError('photo-library', 'latest_photo_load_failed', error),
      );
  }, [permission?.granted]);

  const openPhotoLibrary = useCallback(async () => {
    if (Platform.OS === 'android') {
      await IntentLauncher.startActivityAsync('android.intent.action.VIEW', {
        type: 'vnd.android.cursor.dir/image',
      });
    } else {
      await ImagePicker.launchImageLibraryAsync({
        allowsEditing: false,
        allowsMultipleSelection: false,
        mediaTypes: ['images'],
      });
    }

    if (permission?.granted) {
      await refreshLatestPhoto();
    }
  }, [permission?.granted, refreshLatestPhoto]);

  return {
    latestPhotoUri,
    openPhotoLibrary,
    rememberLatestPhoto: setLatestPhotoUri,
  };
}

async function getLatestPhotoUri(): Promise<string | undefined> {
  const [latestPhoto] = await new Query()
    .eq(AssetField.MEDIA_TYPE, MediaType.IMAGE)
    .orderBy({ key: AssetField.CREATION_TIME, ascending: false })
    .limit(1)
    .exe();

  return latestPhoto?.getUri();
}
