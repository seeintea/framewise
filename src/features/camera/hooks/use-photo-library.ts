import * as ImagePicker from 'expo-image-picker';
import {
  AssetField,
  type GranularPermission,
  MediaType,
  Query,
  usePermissions,
} from 'expo-media-library';
import { useCallback, useEffect, useState } from 'react';

const PHOTO_PERMISSION_OPTIONS = {
  granularPermissions: ['photo'] satisfies GranularPermission[],
  writeOnly: false,
};

export function usePhotoLibrary() {
  const [permission, requestPermission] = usePermissions(
    PHOTO_PERMISSION_OPTIONS,
  );
  const [latestPhotoUri, setLatestPhotoUri] = useState<string>();

  const refreshLatestPhoto = useCallback(async () => {
    setLatestPhotoUri(await getLatestPhotoUri());
  }, []);

  useEffect(() => {
    if (!permission?.granted) {
      return;
    }

    void getLatestPhotoUri().then(setLatestPhotoUri).catch(console.error);
  }, [permission?.granted]);

  const openPhotoLibrary = useCallback(async () => {
    let currentPermission = permission;

    if (!currentPermission?.granted) {
      currentPermission = await requestPermission();
    }

    if (!currentPermission.granted) {
      return;
    }

    await refreshLatestPhoto();
    await ImagePicker.launchImageLibraryAsync({
      allowsEditing: false,
      allowsMultipleSelection: false,
      defaultTab: 'photos',
      mediaTypes: ['images'],
    });
    await refreshLatestPhoto();
  }, [permission, refreshLatestPhoto, requestPermission]);

  return {
    latestPhotoUri: permission?.granted ? latestPhotoUri : undefined,
    openPhotoLibrary,
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
