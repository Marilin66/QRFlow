declare module 'jsqr' {
  export interface Point {
    x: number;
    y: number;
  }

  export interface QRCode {
    binaryData: number[];
    data: string;
    chunks: { type: number; text: string }[];
    version: number;
    location:
      | {
          topRightCorner: Point;
          topLeftCorner: Point;
          bottomRightCorner: Point;
          bottomLeftCorner: Point;
          topRightFinderPattern: Point;
          topLeftFinderPattern: Point;
          bottomLeftFinderPattern: Point;
          bottomRightFinderPattern: Point;
        }
      | undefined;
  }

  export interface JsQROptions {
    inversionAttempts?: 'attemptBoth' | 'dontInvert' | 'onlyInvert' | 'invertFirst';
  }

  export default function jsQR(
    imageData: Uint8ClampedArray,
    width: number,
    height: number,
    options?: JsQROptions,
  ): QRCode | null;
}
