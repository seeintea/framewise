import {
  FontWeight,
  ImageFormat,
  Skia,
  TextAlign,
  type SkImage,
  type SkParagraph,
} from '@shopify/react-native-skia';
import { File, Paths } from 'expo-file-system';

const LABEL_FONT_SCALE = 0.03;
const LABEL_MARGIN_SCALE = 0.03;
const LABEL_HORIZONTAL_PADDING_SCALE = 0.5;
const LABEL_VERTICAL_PADDING_SCALE = 0.28;
const LABEL_CORNER_RADIUS_SCALE = 0.24;
const LABEL_MAX_WIDTH_SCALE = 0.7;

export async function createLabeledPhoto(
  photoUri: string,
  title: string,
): Promise<File> {
  const encodedPhoto = await Skia.Data.fromURI(photoUri);
  const photo = Skia.Image.MakeImageFromEncoded(encodedPhoto);

  if (!photo) {
    encodedPhoto.dispose();
    throw new Error('无法读取拍摄的照片');
  }

  const width = photo.width();
  const height = photo.height();
  const surface = Skia.Surface.Make(width, height);

  if (!surface) {
    photo.dispose();
    encodedPhoto.dispose();
    throw new Error('无法创建照片标注');
  }

  const backgroundPaint = Skia.Paint();
  const paragraphBuilder = Skia.ParagraphBuilder.Make({
    maxLines: 1,
    ellipsis: '…',
    textAlign: TextAlign.Left,
  });
  let paragraph: SkParagraph | undefined;
  let snapshot: SkImage | undefined;

  try {
    const canvas = surface.getCanvas();
    canvas.drawImage(photo, 0, 0);

    const shortSide = Math.min(width, height);
    const fontSize = Math.round(shortSide * LABEL_FONT_SCALE);
    const margin = Math.round(shortSide * LABEL_MARGIN_SCALE);
    const horizontalPadding = Math.round(
      fontSize * LABEL_HORIZONTAL_PADDING_SCALE,
    );
    const verticalPadding = Math.round(fontSize * LABEL_VERTICAL_PADDING_SCALE);
    const maxTextWidth = Math.floor(
      Math.min(
        width * LABEL_MAX_WIDTH_SCALE,
        width - (margin + horizontalPadding) * 2,
      ),
    );

    paragraphBuilder
      .pushStyle({
        color: Skia.Color('#FFFFFF'),
        fontFamilies: ['System'],
        fontSize,
        fontStyle: { weight: FontWeight.SemiBold },
        locale: 'zh-CN',
      })
      .addText(title);
    paragraph = paragraphBuilder.build();
    paragraph.layout(maxTextWidth);

    const textWidth = Math.ceil(paragraph.getLongestLine());
    const textHeight = Math.ceil(paragraph.getHeight());
    const labelWidth = textWidth + horizontalPadding * 2;
    const labelHeight = textHeight + verticalPadding * 2;
    const labelX = width - margin - labelWidth;
    const labelY = height - margin - labelHeight;
    const labelRect = Skia.XYWHRect(labelX, labelY, labelWidth, labelHeight);
    const labelRRect = Skia.RRectXY(
      labelRect,
      fontSize * LABEL_CORNER_RADIUS_SCALE,
      fontSize * LABEL_CORNER_RADIUS_SCALE,
    );

    backgroundPaint.setAntiAlias(true);
    backgroundPaint.setColor(Skia.Color('#000000'));
    backgroundPaint.setAlphaf(0.64);
    canvas.drawRRect(labelRRect, backgroundPaint);
    labelRect.dispose();
    paragraph.paint(
      canvas,
      labelX + horizontalPadding,
      labelY + verticalPadding,
    );

    surface.flush();
    snapshot = surface.makeImageSnapshot();

    const outputFile = new File(
      Paths.cache,
      `framewise-${Date.now()}-${Math.random().toString(36).slice(2)}.jpg`,
    );
    outputFile.write(snapshot.encodeToBytes(ImageFormat.JPEG, 100));
    return outputFile;
  } finally {
    snapshot?.dispose();
    paragraph?.dispose();
    backgroundPaint.dispose();
    surface.dispose();
    photo.dispose();
    encodedPhoto.dispose();
  }
}
