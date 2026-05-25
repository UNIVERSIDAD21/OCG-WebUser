import * as admin from 'firebase-admin';
import {CallableRequest, onCall} from 'firebase-functions/v2/https';
import OpenAI, {toFile} from 'openai';
import sharp from 'sharp';

import {loadSimulatorConfig, openAiApiKeySecret} from './simulator_config';
import {
  GenerateSmileSimulationData,
  processGenerateSmileSimulation,
} from './generate_smile_simulation_core';

// ── Compresión de imagen de entrada para reducir tokens de OpenAI ──
// gpt-image-2 procesa la imagen de referencia en alta fidelidad.
// Comprimir antes de enviar reduce drásticamente los tokens de entrada.
async function compressInputImage(bytes: Buffer): Promise<Buffer> {
  const metadata = await sharp(bytes).metadata();
  const maxDim = 1024; // suficiente para referencia dental
  const w = metadata.width ?? 1024;
  const h = metadata.height ?? 1024;
  const resizeNeeded = w > maxDim || h > maxDim;

  let pipeline = sharp(bytes);
  if (resizeNeeded) {
    pipeline = pipeline.resize(maxDim, maxDim, { fit: 'inside', withoutEnlargement: true });
  }

  const compressed = await pipeline.jpeg({ quality: 80, mozjpeg: true }).toBuffer();

  const savings = ((1 - compressed.length / bytes.length) * 100).toFixed(0);
  console.info('[SimulatorCallable][input.compress]', {
    originalBytes: bytes.length,
    compressedBytes: compressed.length,
    savingsPct: `${savings}%`,
  });

  return compressed;
}

export const generateSmileSimulation = onCall<GenerateSmileSimulationData>(
  {
    region: 'us-central1',
    cors: true,
    secrets: [openAiApiKeySecret],
    timeoutSeconds: 300, // 5 minutos — OpenAI image edit puede tardar 2-3 min
  },
  async (request: CallableRequest<GenerateSmileSimulationData>) => {
    const db = admin.firestore();
    const bucket = admin.storage().bucket();
    const config = loadSimulatorConfig();

    return processGenerateSmileSimulation(
      {
        db,
        storage: {
          download: async (path: string) => {
            console.info('[SimulatorCallable][storage.download]', {
              path,
              bucket: bucket.name,
            });
            const [bytes] = await bucket.file(path).download();
            return bytes;
          },
          save: async (path: string, bytes: Buffer) => {
            await bucket.file(path).save(bytes, {
              metadata: {
                contentType: 'image/jpeg',
                cacheControl: 'private, max-age=31536000',
              },
              resumable: false,
            });
          },
        },
        config,
        auth: {
          uid: request.auth?.uid?.trim() ?? '',
          role:
            typeof request.auth?.token?.role === 'string'
                ? request.auth?.token?.role
                : undefined,
          admin: request.auth?.token?.admin === true,
        },
        loadAdminRole: async (uid: string) => {
          const adminDoc = await db.collection('admins').doc(uid).get();
          return adminDoc.exists ? (adminDoc.data()?.['role'] ?? null) : null;
        },
        createOpenAiClient: (apiKey: string) => ({
          generateEditedImage: async ({originalBytes, prompt, model, size, quality}) => {
            // Comprimir la imagen de entrada antes de enviarla a OpenAI
            // para reducir tokens de entrada y bajar costos
            const inputBytes = await compressInputImage(originalBytes);

            const client = new OpenAI({apiKey});
            const originalFile = await toFile(inputBytes, 'original.jpg', {
              type: 'image/jpeg',
            });
            const response = await client.images.edit({
              model,
              image: originalFile,
              prompt,
              size: size as
                | 'auto'
                | '1024x1024'
                | '256x256'
                | '512x512'
                | '1536x1024'
                | '1024x1536',
              quality: quality as 'low' | 'medium' | 'high' | 'auto',
            });
            const base64 = response.data?.[0]?.b64_json?.trim();
            if (!base64) {
              throw new Error('OpenAI no devolvió una imagen generada válida.');
            }
            return Buffer.from(base64, 'base64');
          },
        }),
      },
      request.data ?? {},
    );
  },
);
