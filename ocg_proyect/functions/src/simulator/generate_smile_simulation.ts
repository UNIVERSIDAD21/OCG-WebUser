import * as admin from 'firebase-admin';
import {CallableRequest, onCall} from 'firebase-functions/v2/https';
import OpenAI, {toFile} from 'openai';

import {loadSimulatorConfig, openAiApiKeySecret} from './simulator_config';
import {
  GenerateSmileSimulationData,
  processGenerateSmileSimulation,
} from './generate_smile_simulation_core';

export const generateSmileSimulation = onCall<GenerateSmileSimulationData>(
  {
    region: 'us-central1',
    cors: true,
    secrets: [openAiApiKeySecret],
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
            const client = new OpenAI({apiKey});
            const originalFile = await toFile(originalBytes, 'original.jpg', {
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
