/**
 * Type declarations for the BarcodeDetector API (W3C Shape Detection API).
 * https://developer.mozilla.org/en-US/docs/Web/API/BarcodeDetector
 *
 * Supported in Chrome 83+, Edge 83+, Safari 17+.
 * Falls back to jsQR when unavailable.
 */

type BarcodeFormat =
  | 'aztec'
  | 'code_128'
  | 'code_39'
  | 'code_93'
  | 'codabar'
  | 'data_matrix'
  | 'ean_13'
  | 'ean_8'
  | 'itf'
  | 'qr_code'
  | 'upc_a'
  | 'upc_e'
  | 'pdf417';

interface BarcodeDetectorOptions {
  formats?: BarcodeFormat[];
}

interface DetectedBarcode {
  readonly boundingBox: DOMRectReadOnly;
  readonly corners: readonly DOMPoint[];
  readonly format: BarcodeFormat;
  readonly rawValue: string;
}

interface BarcodeDetectorResult {
  readonly barcodes: readonly DetectedBarcode[];
}

declare class BarcodeDetector {
  constructor(options?: BarcodeDetectorOptions);
  detect(source: ImageBitmapSource): Promise<BarcodeDetectorResult>;
  static getSupportedFormats(): Promise<readonly BarcodeFormat[]>;
}
